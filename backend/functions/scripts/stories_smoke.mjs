/** Demo-emulator-only evidence for all six story lessons and content edits. */
import assert from "node:assert/strict";
import { randomBytes } from "node:crypto";
import { initializeApp, getApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore, Timestamp } from "firebase-admin/firestore";

for (const key of ["FIRESTORE_EMULATOR_HOST","FIREBASE_AUTH_EMULATOR_HOST"]) {
  assert.match(process.env[key] ?? "",/^(localhost|127\.0\.0\.1):\d+$/);
}
initializeApp({projectId:"demo-letrando"});
const auth=getAuth(), db=getFirestore();
const users=[], contentRefs=[];
async function parent() {
  const password=randomBytes(24).toString("base64url");
  const user=await auth.createUser({email:`story-${randomBytes(6).toString("hex")}@example.test`,password,emailVerified:true});
  users.push(user.uid);
  for(let attempt=0;attempt<50;attempt++) {
    if((await db.doc(`users/${user.uid}`).get()).get("onboardingState")) break;
    await new Promise(resolve=>setTimeout(resolve,100));
  }
  const login=await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=demo-api-key`,{
    method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({email:user.email,password,returnSecureToken:true}),
  }).then(response=>response.json());
  assert.ok(login.idToken);
  return {uid:user.uid,token:login.idToken};
}
const call=(name,parent,data)=>fetch(`http://127.0.0.1:5001/demo-letrando/southamerica-east1/${name}`,{
  method:"POST",headers:{Authorization:`Bearer ${parent.token}`,"Content-Type":"application/json"},body:JSON.stringify({data}),
}).then(response=>response.json());
try {
  const owner=await parent(), stranger=await parent();
  const child=(await call("createChildProfile",owner,{requestId:randomBytes(12).toString("hex"),profile:{name:"Leitor",age:6,avatarId:"teal"}})).result?.childId;
  assert.ok(child);
  const childRef=db.doc(`users/${owner.uid}/children/${child}`);
  // Trusted synthetic placement/entitlement, only for this temporary account.
  await childRef.update({currentCourseId:"course_001",currentLessonId:"lesson_032"});
  const entitlement=db.doc(`users/${owner.uid}/entitlements/premium`);
  const premium=()=>entitlement.set({active:true,features:["full_curriculum"],validFrom:Timestamp.fromMillis(Date.now()-60_000),validUntil:Timestamp.fromMillis(Date.now()+3600_000)});
  assert.equal((await call("startLessonSession",owner,{childId:child,lessonId:"lesson_032",contentVersion:2})).error?.status,"PERMISSION_DENIED");
  await premium();

  async function answer(id,activity,response,requestId=randomBytes(12).toString("hex")) {
    return call("submitActivityAttempt",owner,{childId:child,sessionId:id,activityId:activity.id,requestId,response});
  }
  async function exercises(id) {
    const session=(await db.doc(`users/${owner.uid}/sessions/${id}`).get()).data();
    for(const activityId of session.activityIds.slice(0,4)) {
      const activity=(await db.doc(`activities/${activityId}`).get()).data();
      const responses=activity.type==="match" ? activity.pairs : activity.type==="trace"
        ? [{strokeCount:1,pointCount:8,durationMillis:500}]
        : [{selectedLabel:activity.options.find(option=>option.correct).label}];
      for(const response of responses) assert.equal((await answer(id,activity,response)).result?.correct,true);
    }
    const activity=(await db.doc(`activities/${session.activityIds[4]}`).get()).data();
    const story=(await db.doc(`stories/${activity.storyId}`).get()).data();
    return {activity,story};
  }
  for(let number=32;number<=37;number++) {
    const lessonId=`lesson_${String(number).padStart(3,"0")}`;
    const started=await call("startLessonSession",owner,{childId:child,lessonId,contentVersion:2});
    const id=started.result?.sessionId;
    assert.ok(id,JSON.stringify(started));
    const complete=()=>call("completeLesson",owner,{childId:child,lessonId,sessionId:id});
    const {activity,story}=await exercises(id);
    assert.equal((await complete()).error?.status,"FAILED_PRECONDITION","Story cannot be skipped");
    const first=story.questions[0];
    assert.equal((await answer(id,activity,{questionId:first.id,selectedLabel:first.options.find(option=>option!==first.answer),correct:true})).result?.correct,false);
    const data={childId:child,sessionId:id,activityId:activity.id,requestId:randomBytes(12).toString("hex"),response:{questionId:first.id,selectedLabel:first.answer}};
    assert.equal((await call("submitActivityAttempt",stranger,data)).error?.status,"NOT_FOUND");
    const result=await call("submitActivityAttempt",owner,data);
    assert.equal((await db.doc(`users/${owner.uid}/activityAttempts/${id}_${data.requestId}`).get()).get("response.questionId"),first.id);
    assert.equal(result.result?.activityCompleted,false);
    assert.deepEqual((await call("submitActivityAttempt",owner,data)).result,result.result);
    assert.equal((await complete()).error?.status,"FAILED_PRECONDITION","Every question must finish");
    const recovery=await call("recoverLessonSession",owner,{childId:child,lessonId,sessionId:id});
    assert.equal(recovery.result?.nextActivityIndex,4);
    assert.deepEqual(recovery.result.activityProgress[activity.id].completedItems,[first.id]);
    if(number===32) {
      await entitlement.update({validUntil:Timestamp.fromMillis(Date.now()-1)});
      assert.equal((await call("recoverLessonSession",owner,{childId:child,lessonId,sessionId:id})).error?.status,"PERMISSION_DENIED");
      assert.equal((await answer(id,activity,{questionId:story.questions[1].id,selectedLabel:story.questions[1].answer})).error?.status,"PERMISSION_DENIED");
      await premium();
    }
    for(const question of story.questions.slice(1)) assert.equal((await answer(id,activity,{questionId:question.id,selectedLabel:question.answer})).result?.correct,true);
    const parallel=await Promise.all([complete(),complete()]);
    assert.equal(parallel.filter(response=>response.result?.awarded).length,1);
    assert.equal((await complete()).result?.xpEarned,0);
  }
  assert.equal((await db.doc(`users/${owner.uid}/gamification/${child}`).get()).get("xp"),300);
  const week=(await call("getWeeklyLearningSummary",owner,{childId:child})).result;
  assert.equal(week.days.reduce((sum,day)=>sum+day.lessonsCompleted,0),6);

  // Edit only a namespaced disposable content fixture, never the real catalog.
  const cloneId=`smoke_story_${randomBytes(8).toString("hex")}`;
  const original=(await db.doc("lessons/lesson_032").get()).data();
  const ids=[];
  let cloneStory;
  for(const activityId of original.activityIds) {
    const activity=(await db.doc(`activities/${activityId}`).get()).data();
    const id=`${cloneId}_${activity.type}`;
    const ref=db.doc(`activities/${id}`); contentRefs.push(ref); ids.push(id);
    if(activity.type==="story") {
      cloneStory={...(await db.doc(`stories/${activity.storyId}`).get()).data(),id:cloneId,lessonId:cloneId};
      const storyRef=db.doc(`stories/${cloneId}`); contentRefs.push(storyRef); await storyRef.set(cloneStory);
    }
    await ref.set({...activity,id,lessonId:cloneId,...(activity.type==="story" ? {storyId:cloneId} : {})});
  }
  const lessonRef=db.doc(`lessons/${cloneId}`); contentRefs.push(lessonRef);
  await lessonRef.set({...original,id:cloneId,number:1000,activityIds:ids});
  await childRef.update({currentLessonId:cloneId});
  assert.equal((await call("startLessonSession",owner,{childId:child,lessonId:cloneId,contentVersion:1})).error?.status,"FAILED_PRECONDITION");
  const id=(await call("startLessonSession",owner,{childId:child,lessonId:cloneId,contentVersion:2})).result?.sessionId;
  assert.ok(id);
  const {activity,story}=await exercises(id);
  for(const question of story.questions) await answer(id,activity,{questionId:question.id,selectedLabel:question.answer});
  await db.doc(`stories/${cloneId}`).update({questions:story.questions.map((question,index)=>index===0 ? {...question,answer:question.options.find(option=>option!==question.answer)} : question)});
  assert.equal((await call("completeLesson",owner,{childId:child,lessonId:cloneId,sessionId:id})).error?.status,"FAILED_PRECONDITION");
  assert.equal((await call("updateLessonSession",owner,{childId:child,sessionId:id,action:"heartbeat",sequence:1})).error?.status,"FAILED_PRECONDITION");
  assert.equal((await call("recoverLessonSession",owner,{childId:child,lessonId:cloneId,sessionId:id})).error?.status,"FAILED_PRECONDITION");
  assert.equal((await db.doc(`users/${owner.uid}/gamification/${child}`).get()).get("xp"),300);
  console.log("PASS: all six stories, required questions, trusted scoring, retries, concurrency, expiry, ownership and edited-content rejection.");
} finally {
  for(const ref of contentRefs) await ref.delete();
  for(const uid of users) { await db.recursiveDelete(db.doc(`users/${uid}`)); await auth.deleteUser(uid); }
  await getApp().delete();
}
