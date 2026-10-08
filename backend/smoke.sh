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

CREATE_CHILD=$(curl -s -X POST "${FN}/createChildProfile" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d "{\"data\":{\"requestId\":\"smoke_${UID_}\",\"profile\":{\"name\":\"Sofia\",\"age\":5,\"avatarId\":\"orange\"}}}")
CHILD_ID=$(python3 -c "import sys,json;print(json.load(sys.stdin).get('result',{}).get('childId',''))" <<<"$CREATE_CHILD")
[ -n "$CHILD_ID" ] && r=ok || r=no
check "backend creates a child with a server-generated ID" "$r" "($CHILD_ID)"
CREATE_CHILD_RETRY=$(curl -s -X POST "${FN}/createChildProfile" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d "{\"data\":{\"requestId\":\"smoke_${UID_}\",\"profile\":{\"name\":\"Sofia\",\"age\":5,\"avatarId\":\"orange\"}}}")
RETRIED_CHILD_ID=$(python3 -c "import sys,json;print(json.load(sys.stdin).get('result',{}).get('childId',''))" <<<"$CREATE_CHILD_RETRY")
[ "$RETRIED_CHILD_ID" = "$CHILD_ID" ] && r=ok || r=no
check "retrying profile creation returns the same child ID" "$r"

CHILD=$(curl -s -X PATCH "${FS}/users/${UID_}/children/${CHILD_ID}?updateMask.fieldPaths=avatarId" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"fields":{"avatarId":{"stringValue":"purple"}}}')
grep -q '"name"' <<<"$CHILD" && r=ok || r=no
check "child profile passes Security Rules" "$r"

# Deliberately not the default avatar, so a pass can't be the default
# leaking through.
STORED=$(curl -s "${FS}/users/${UID_}/children/${CHILD_ID}" -H "Authorization: Bearer $TOKEN" \
  | python3 -c "import sys,json;print(json.load(sys.stdin)['fields'].get('avatarId',{}).get('stringValue',''))")
[ "$STORED" = "purple" ] && r=ok || r=no
check "the chosen avatar is stored and reads back" "$r" "($STORED)"

# Forbidden by the child-data constraint (spec §19).
PII=$(curl -s -X PATCH "${FS}/users/${UID_}/children/${CHILD_ID}" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"fields":{"school":{"stringValue":"Escola X"}}}')
grep -q 'PERMISSION_DENIED' <<<"$PII" && r=ok || r=no
check "child PII write is denied" "$r"

ASSESS=$(curl -s -X POST "${FN}/submitAssessment" -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d "{\"data\":{\"childId\":\"$CHILD_ID\",\"answers\":{\"q_letters\":\"some\",\"q_writes_name\":\"not_yet\",\"q_reading_together\":\"rarely\"}}}")
SCORE=$(python3 -c "import sys,json;print(json.load(sys.stdin).get('result',{}).get('score',''))" <<<"$ASSESS")
[ "$SCORE" = "1" ] && r=ok || r=no
check "assessment scored server-side" "$r" "(score=$SCORE)"

PLACED=$(curl -s "${FS}/users/${UID_}/children/${CHILD_ID}" -H "Authorization: Bearer $TOKEN")
LESSON=$(python3 -c "import sys,json;print(json.load(sys.stdin)['fields'].get('currentLessonId',{}).get('stringValue',''))" <<<"$PLACED")
[ -n "$LESSON" ] && r=ok || r=no
check "placement written to the child" "$r" "(currentLessonId=$LESSON)"

# The parent can edit a child's name, but cannot jump the server-owned
# journey to the last lesson or mint a completion for a made-up lesson.
FORGED_PLACEMENT=$(curl -s -X PATCH "${FS}/users/${UID_}/children/${CHILD_ID}?updateMask.fieldPaths=currentLessonId" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"fields":{"currentLessonId":{"stringValue":"lesson_037"}}}')
grep -q 'PERMISSION_DENIED' <<<"$FORGED_PLACEMENT" && r=ok || r=no
check "client cannot skip the learning journey" "$r"

FAKE_LESSON=$(curl -s -X POST "${FN}/completeLesson" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d "{\"data\":{\"childId\":\"$CHILD_ID\",\"lessonId\":\"lesson_invented\",\"sessionId\":\"invented\"}}")
grep -q 'NOT_FOUND' <<<"$FAKE_LESSON" && r=ok || r=no
check "invented lesson cannot grant a reward" "$r"

PREMIUM_START=$(curl -s -X POST "${FN}/startLessonSession" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d "{\"data\":{\"childId\":\"$CHILD_ID\",\"lessonId\":\"lesson_004\"}}")
grep -q 'PERMISSION_DENIED' <<<"$PREMIUM_START" && r=ok || r=no
check "server denies a later module without Premium" "$r"

START=$(curl -s -X POST "${FN}/startLessonSession" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d "{\"data\":{\"childId\":\"$CHILD_ID\",\"lessonId\":\"$LESSON\"}}")
SESSION=$(python3 -c "import sys,json;print(json.load(sys.stdin).get('result',{}).get('sessionId',''))" <<<"$START")
[ -n "$SESSION" ] && r=ok || r=no
check "backend creates a lesson session" "$r"

INCOMPLETE=$(curl -s -X POST "${FN}/completeLesson" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d "{\"data\":{\"childId\":\"$CHILD_ID\",\"lessonId\":\"$LESSON\",\"sessionId\":\"$SESSION\",\"score\":100,\"attempts\":4,\"correctAnswers\":4}}")
grep -q 'FAILED_PRECONDITION' <<<"$INCOMPLETE" && r=ok || r=no
check "client cannot complete a session without activity evidence" "$r"

SESSION_DOC=$(curl -s "${FS}/users/${UID_}/sessions/${SESSION}" -H "Authorization: Bearer $TOKEN")
ACTIVITY_LIST=$(python3 -c "import sys,json; f=json.load(sys.stdin)['fields']['activityIds']['arrayValue']['values']; print(','.join(x['stringValue'] for x in f))" <<<"$SESSION_DOC")
IFS=, read -r -a ACTIVITY_IDS <<<"$ACTIVITY_LIST"
submit_attempt() {
  local activity_id="$1"
  local response_json="$2"
  # Callers supply the logical request ID: $(submit_attempt ...) runs in a
  # subshell, so incrementing a global counter here would reset on each call
  # and make different answers look like retries of the first wrong answer.
  local request_id="$3"
  local payload
  payload=$(python3 -c 'import json,sys; print(json.dumps({"data":{"childId":sys.argv[1],"sessionId":sys.argv[2],"activityId":sys.argv[3],"requestId":sys.argv[4],"response":json.loads(sys.argv[5])}},separators=(",",":")))' \
    "$CHILD_ID" "$SESSION" "$activity_id" "$request_id" "$response_json")
  curl -s -X POST "${FN}/submitActivityAttempt" \
    -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
    -d "$payload"
}

for ACTIVITY_ID in "${ACTIVITY_IDS[@]}"; do
  ACTIVITY=$(curl -s "${FS}/activities/${ACTIVITY_ID}" -H "Authorization: Bearer $TOKEN")
  TYPE=$(python3 -c "import sys,json;print(json.load(sys.stdin)['fields']['type']['stringValue'])" <<<"$ACTIVITY")
  case "$TYPE" in
    tap)
      LABELS=$(python3 -c 'import json,sys; f=json.load(sys.stdin)["fields"]; a=[x["mapValue"]["fields"] for x in f["options"]["arrayValue"]["values"]]; good=next(x["label"]["stringValue"] for x in a if x["correct"]["booleanValue"]); bad=next(x["label"]["stringValue"] for x in a if not x["correct"]["booleanValue"]); print(json.dumps([bad,good]))' <<<"$ACTIVITY")
      BAD=$(python3 -c "import sys,json;print(json.dumps({'selectedLabel':json.loads(sys.argv[1])[0]}))" "$LABELS")
      GOOD=$(python3 -c "import sys,json;print(json.dumps({'selectedLabel':json.loads(sys.argv[1])[1]}))" "$LABELS")
      WRONG=$(submit_attempt "$ACTIVITY_ID" "$BAD" "smoke_${ACTIVITY_ID}_wrong")
      grep -q '"correct":false' <<<"$WRONG" && r=ok || r=no
      check "backend marks a wrong tap answer incorrect" "$r"
      RIGHT=$(submit_attempt "$ACTIVITY_ID" "$GOOD" "smoke_${ACTIVITY_ID}_correct")
      grep -q '"correct":true' <<<"$RIGHT" && r=ok || r=no
      check "backend scores the correct tap answer" "$r"
      # A changed payload with the same ID must still return the stored score.
      DUPLICATE=$(submit_attempt "$ACTIVITY_ID" "$BAD" "smoke_${ACTIVITY_ID}_correct")
      grep -q '"correct":true' <<<"$DUPLICATE" && r=ok || r=no
      check "repeated request ID returns the stored score" "$r"
      ;;
    match)
      PAIRS=$(python3 -c 'import json,sys; f=json.load(sys.stdin)["fields"]; [print(json.dumps({"upper":x["mapValue"]["fields"]["upper"]["stringValue"],"lower":x["mapValue"]["fields"]["lower"]["stringValue"]})) for x in f["pairs"]["arrayValue"]["values"]]' <<<"$ACTIVITY")
      pair_number=0
      r=ok
      while IFS= read -r PAIR; do
        pair_number=$((pair_number + 1))
        MATCH=$(submit_attempt "$ACTIVITY_ID" "$PAIR" "smoke_${ACTIVITY_ID}_pair_${pair_number}")
        if ! grep -q '"correct":true' <<<"$MATCH"; then
          r=no
          break
        fi
      done <<<"$PAIRS"
      check "backend scores every published letter pair" "$r"
      ;;
    trace)
      TRACE='{"strokeCount":1,"pointCount":8,"durationMillis":500}'
      RESULT=$(submit_attempt "$ACTIVITY_ID" "$TRACE" "smoke_${ACTIVITY_ID}_trace")
      grep -q '"activityCompleted":true' <<<"$RESULT" && r=ok || r=no
      check "backend accepts bounded trace gesture metadata" "$r"
      ;;
    listen)
      GOOD=$(python3 -c 'import json,sys; f=json.load(sys.stdin)["fields"]; a=[x["mapValue"]["fields"] for x in f["options"]["arrayValue"]["values"]]; label=next(x["label"]["stringValue"] for x in a if x["correct"]["booleanValue"]); print(json.dumps({"selectedLabel":label}))' <<<"$ACTIVITY")
      RESULT=$(submit_attempt "$ACTIVITY_ID" "$GOOD" "smoke_${ACTIVITY_ID}_listen")
      grep -q '"correct":true' <<<"$RESULT" && r=ok || r=no
      check "backend scores the correct listening answer" "$r"
      ;;
    *)
      check "session contains only supported activity types" no "($TYPE)"
      ;;
  esac
done

reward() {
  curl -s -X POST "${FN}/completeLesson" -H "Authorization: Bearer $TOKEN" \
    -H 'Content-Type: application/json' \
    -d "{\"data\":{\"childId\":\"$CHILD_ID\",\"lessonId\":\"$LESSON\",\"sessionId\":\"$SESSION\",\"score\":0,\"attempts\":0,\"correctAnswers\":999,\"durationSeconds\":0}}"
}
FIRST=$(reward)
python3 -c "
import sys,json
r=json.load(sys.stdin).get('result',{})
sys.exit(0 if r.get('awarded') and r.get('xpEarned')==50 and r.get('streak')==1 else 1)" <<<"$FIRST" && r=ok || r=no
check "completeLesson granted the reward" "$r" "$(python3 -c "import sys,json;r=json.load(sys.stdin).get('result',{});print('xp=%s streak=%s'%(r.get('xp'),r.get('streak')))" <<<"$FIRST")"

STATS=$(curl -s "${FS}/users/${UID_}/learningProgress/${CHILD_ID}_${LESSON}" -H "Authorization: Bearer $TOKEN")
python3 -c 'import sys,json; f=json.load(sys.stdin)["fields"]; ok=(f["score"]["integerValue"]=="86" and f["attempts"]["integerValue"]=="7" and f["correctAnswers"]["integerValue"]=="6" and f["wrongAnswers"]["integerValue"]=="1"); sys.exit(0 if ok else 1)' <<<"$STATS" && r=ok || r=no
check "persisted stats come from scored answers, not client values" "$r"

NEXT=$(python3 -c "import sys,json;print(json.load(sys.stdin).get('result',{}).get('nextLessonId') or '')" <<<"$FIRST")
AFTER=$(curl -s "${FS}/users/${UID_}/children/${CHILD_ID}" -H "Authorization: Bearer $TOKEN" \
  | python3 -c "import sys,json;print(json.load(sys.stdin)['fields'].get('currentLessonId',{}).get('stringValue',''))")
[ -n "$NEXT" ] && [ "$AFTER" = "$NEXT" ] && [ "$AFTER" != "$LESSON" ] && r=ok || r=no
check "finishing a lesson moves the child to the next one" "$r" "($LESSON -> $AFTER)"

SECOND=$(reward)
python3 -c "
import sys,json
r=json.load(sys.stdin).get('result',{})
sys.exit(0 if r.get('awarded') is False and r.get('xpEarned')==0 and r.get('xp')==50 else 1)" <<<"$SECOND" && r=ok || r=no
check "replaying the lesson grants nothing extra" "$r"

# The child has already moved on, so replaying an old lesson must not drag
# them backwards or push them forward again.
STILL=$(curl -s "${FS}/users/${UID_}/children/${CHILD_ID}" -H "Authorization: Bearer $TOKEN" \
  | python3 -c "import sys,json;print(json.load(sys.stdin)['fields'].get('currentLessonId',{}).get('stringValue',''))")
[ "$STILL" = "$AFTER" ] && r=ok || r=no
check "replaying an old lesson leaves the position alone" "$r" "($STILL)"

MINT=$(curl -s -X PATCH "${FS}/users/${UID_}/gamification/${CHILD_ID}" \
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
