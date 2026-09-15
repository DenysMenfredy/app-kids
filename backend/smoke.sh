#!/usr/bin/env bash
#
# End-to-end check against the running local backend (start it with ./dev.sh).
#
# Walks the whole vertical slice the app depends on — sign-up, the profile
# bootstrap trigger, a rules-enforced child write, server-side assessment
# scoring, reward granting and its idempotency, and the denial of a client
# trying to mint its own XP. Useful both as "is my local setup working" and
# as a regression check that exercises Auth, Firestore rules and Functions
# together, which the unit suites can't.
set -uo pipefail

PROJECT="demo-letrando"
AUTH="http://localhost:9099/identitytoolkit.googleapis.com/v1"
FS="http://localhost:8080/v1/projects/${PROJECT}/databases/(default)/documents"
FN="http://localhost:5001/${PROJECT}/southamerica-east1"

failures=0
check() { # check <label> <condition-result> <detail>
  if [ "$2" = "ok" ]; then
    printf '  \033[32m✓\033[0m %s %s\n' "$1" "${3:-}"
  else
    printf '  \033[31m✗\033[0m %s %s\n' "$1" "${3:-}"
    failures=$((failures + 1))
  fi
}

if ! curl -sf -o /dev/null "http://localhost:8080/"; then
  echo "Firestore emulator is not running. Start it with ./dev.sh" >&2
  exit 1
fi

echo "Signing up a parent"
EMAIL="smoke+${RANDOM}${RANDOM}@example.com"
RESP=$(curl -s -X POST "${AUTH}/accounts:signUp?key=demo-api-key" \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"${EMAIL}\",\"password\":\"segredo123\",\"returnSecureToken\":true}")
TOKEN=$(python3 -c "import sys,json;print(json.load(sys.stdin).get('idToken',''))" <<<"$RESP")
UID_=$(python3 -c "import sys,json;print(json.load(sys.stdin).get('localId',''))" <<<"$RESP")
if [ -z "$TOKEN" ]; then
  echo "Sign-up failed: $RESP" >&2
  exit 1
fi
check "signed up" ok "($UID_)"

# The app writes the parent's name straight after sign-up, before the auth
# trigger has necessarily run. Do the same here: the name must survive.
curl -s -X PATCH "${FS}/users/${UID_}?updateMask.fieldPaths=displayName" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"fields":{"displayName":{"stringValue":"Camila"}}}' >/dev/null

# onUserCreated is an auth trigger, so give it a moment to land.
sleep 3
PROFILE=$(curl -s "${FS}/users/${UID_}" -H "Authorization: Bearer $TOKEN")
grep -q '"onboardingState"' <<<"$PROFILE" && r=ok || r=no
check "onUserCreated bootstrapped the profile" "$r"

grep -q '"Camila"' <<<"$PROFILE" && r=ok || r=no
check "the parent's name survived the bootstrap trigger" "$r"

ENT=$(curl -s "${FS}/users/${UID_}/entitlements/premium" -H "Authorization: Bearer $TOKEN")
grep -q '"booleanValue": false' <<<"$ENT" && r=ok || r=no
check "premium starts inactive" "$r"

CHILD=$(curl -s -X PATCH "${FS}/users/${UID_}/children/primary" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"fields":{"name":{"stringValue":"Sofia"},"age":{"integerValue":"5"},"avatarId":{"stringValue":"orange"}}}')
grep -q '"name"' <<<"$CHILD" && r=ok || r=no
check "child profile passes Security Rules" "$r"

# Forbidden by the child-data constraint (spec §19).
PII=$(curl -s -X PATCH "${FS}/users/${UID_}/children/primary" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"fields":{"school":{"stringValue":"Escola X"}}}')
grep -q 'PERMISSION_DENIED' <<<"$PII" && r=ok || r=no
check "child PII write is denied" "$r"

ASSESS=$(curl -s -X POST "${FN}/submitAssessment" -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"data":{"childId":"primary","answers":{"q_letters":"most","q_writes_name":"alone","q_reading_together":"daily"}}}')
SCORE=$(python3 -c "import sys,json;print(json.load(sys.stdin).get('result',{}).get('score',''))" <<<"$ASSESS")
[ "$SCORE" = "6" ] && r=ok || r=no
check "assessment scored server-side" "$r" "(score=$SCORE)"

PLACED=$(curl -s "${FS}/users/${UID_}/children/primary" -H "Authorization: Bearer $TOKEN")
LESSON=$(python3 -c "import sys,json;print(json.load(sys.stdin)['fields'].get('currentLessonId',{}).get('stringValue',''))" <<<"$PLACED")
[ -n "$LESSON" ] && r=ok || r=no
check "placement written to the child" "$r" "(currentLessonId=$LESSON)"

reward() {
  curl -s -X POST "${FN}/completeLesson" -H "Authorization: Bearer $TOKEN" \
    -H 'Content-Type: application/json' \
    -d "{\"data\":{\"childId\":\"primary\",\"lessonId\":\"$LESSON\",\"score\":100,\"attempts\":4,\"correctAnswers\":4,\"durationSeconds\":600}}"
}
FIRST=$(reward)
python3 -c "
import sys,json
r=json.load(sys.stdin).get('result',{})
sys.exit(0 if r.get('awarded') and r.get('xpEarned')==50 and r.get('streak')==1 else 1)" <<<"$FIRST" && r=ok || r=no
check "completeLesson granted the reward" "$r" "$(python3 -c "import sys,json;r=json.load(sys.stdin).get('result',{});print('xp=%s streak=%s'%(r.get('xp'),r.get('streak')))" <<<"$FIRST")"

SECOND=$(reward)
python3 -c "
import sys,json
r=json.load(sys.stdin).get('result',{})
sys.exit(0 if r.get('awarded') is False and r.get('xpEarned')==0 and r.get('xp')==50 else 1)" <<<"$SECOND" && r=ok || r=no
check "replaying the lesson grants nothing extra" "$r"

MINT=$(curl -s -X PATCH "${FS}/users/${UID_}/gamification/primary" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"fields":{"xp":{"integerValue":"999999"}}}')
grep -q 'PERMISSION_DENIED' <<<"$MINT" && r=ok || r=no
check "client cannot mint XP" "$r"

echo
if [ "$failures" -eq 0 ]; then
  echo "All checks passed."
else
  echo "$failures check(s) failed." >&2
  exit 1
fi
