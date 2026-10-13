import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, it } from "node:test";
import { LessonBundle, lessonFingerprint, lessonPublicationProblem, scoredActivities, storyPublicationProblem } from "./lesson_content";
import { ActivityDocument, isActivityComplete, scoreActivityResponse, summarizeLessonSession } from "./lesson_sessions";

const read = (file: string): Record<string, any>[] => JSON.parse(readFileSync(join(__dirname,"../../../seed",file),"utf8"));
const lessons = read("lessons/lessons.json");
const activities = [...read("activities/activities.json"),...read("activities/stories.json")];
const stories = read("stories/stories.json");
function bundleFor(lesson: Record<string, any>): LessonBundle {
  const own = lesson.activityIds.map((id: string) => activities.find((activity) => activity.id===id)) as ActivityDocument[];
  return {lesson, activities:own, story:stories.find((story) => story.id===own[4]?.storyId) ?? null};
}

describe("versioned lesson and story publication", () => {
  it("validates the closed 37-lesson, six-story launch manifest", () => {
    assert.equal(lessons.length,37);
    assert.equal(stories.length,6);
    for (const lesson of lessons) assert.equal(lessonPublicationProblem(lesson.id,bundleFor(lesson)),null,lesson.id);
    assert.equal(lessons.filter((lesson) => lesson.activityIds.length===5).length,6);
  });
  it("rejects missing answers, unsupported media, duplicate IDs and missing pages", () => {
    const story = stories[0];
    assert.ok(storyPublicationProblem({...story,pages:[]}));
    assert.ok(storyPublicationProblem({...story,questions:[{...story.questions[0],answer:"invented"}]}));
    assert.ok(storyPublicationProblem({...story,pages:[{...story.pages[0],imageUrl:"https://example.test/image"}]}));
    assert.ok(storyPublicationProblem({...story,questions:[story.questions[0],story.questions[0]]}));
    assert.ok(storyPublicationProblem({...story,schemaVersion:99}));
    const bundle=bundleFor(lessons[31]);
    assert.ok(lessonPublicationProblem(lessons[31].id,{...bundle,story:null}));
    assert.ok(lessonPublicationProblem(lessons[31].id,{...bundle,activities:[...bundle.activities.slice(0,4),{...bundle.activities[4],type:"video"}]}));
  });
  it("pins pedagogy and versions while ignoring audit-only changes", () => {
    const bundle=bundleFor(lessons[31]);
    const fingerprint=lessonFingerprint(bundle);
    assert.equal(lessonFingerprint({...bundle,lesson:{...bundle.lesson,updatedAt:new Date(),updatedBy:"editor"}}),fingerprint);
    assert.notEqual(lessonFingerprint({...bundle,story:{...bundle.story,contentVersion:2}}),fingerprint);
    assert.notEqual(lessonFingerprint({...bundle,story:{...bundle.story,pages:[{...stories[0].pages[0],text:"Texto novo."}]}}),fingerprint);
  });
});

describe("server-scored story comprehension", () => {
  const bundle=bundleFor(lessons[31]);
  const scored=scoredActivities(bundle);
  const activity=scored[4];
  const questions=stories[0].questions;
  it("scores from trusted question IDs and options, never client correctness", () => {
    assert.equal(scoreActivityResponse(activity,{questionId:questions[0].id,selectedLabel:questions[0].options[1],correct:true}).correct,false);
    assert.deepEqual(scoreActivityResponse(activity,{questionId:questions[0].id,selectedLabel:questions[0].answer}),{correct:true,completionKey:questions[0].id});
    assert.throws(()=>scoreActivityResponse(activity,{questionId:"unknown",selectedLabel:questions[0].answer}));
    assert.throws(()=>scoreActivityResponse(activity,{questionId:questions[0].id,selectedLabel:"unknown"}));
  });
  it("requires all questions even when the completed flag is forged", () => {
    assert.equal(isActivityComplete(activity,{completed:true,completedItems:[questions[0].id]}),false);
    const progress=Object.fromEntries(scored.slice(0,4).map((item)=>[item.id,{completed:true,completedItems:item.type==="match" ? (item.pairs as {upper:string}[]).map(pair=>pair.upper) : ["complete"],attempts:1,correctAnswers:1,wrongAnswers:0}]));
    assert.throws(()=>summarizeLessonSession(scored,progress,20),/incomplete/);
    progress[activity.id]={completed:true,completedItems:questions.map((question: Record<string,unknown>)=>String(question.id)),attempts:3,correctAnswers:2,wrongAnswers:1};
    assert.equal(summarizeLessonSession(scored,progress,20).attempts,7);
    assert.equal(summarizeLessonSession(scored,progress,20).correctAnswers,6);
  });
});
