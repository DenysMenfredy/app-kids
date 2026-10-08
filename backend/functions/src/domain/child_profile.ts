export const CHILD_AVATARS = ["orange", "teal", "purple", "yellow"] as const;

export interface ChildProfileInput {
  name: string;
  age: number;
  avatarId: (typeof CHILD_AVATARS)[number];
}

export function parseChildProfile(value: unknown): ChildProfileInput | null {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    return null;
  }
  const data = value as Record<string, unknown>;
  if (Object.keys(data).some((key) =>
    !["name", "age", "avatarId"].includes(key)
  )) {
    return null;
  }
  if (typeof data.name !== "string") return null;
  const name = data.name.trim();
  if (name.length === 0 || name.length > 80) return null;
  if (
    typeof data.age !== "number" || !Number.isInteger(data.age) ||
    data.age < 3 || data.age > 7
  ) {
    return null;
  }
  if (
    typeof data.avatarId !== "string" ||
    !CHILD_AVATARS.includes(data.avatarId as ChildProfileInput["avatarId"])
  ) {
    return null;
  }
  return {
    name,
    age: data.age,
    avatarId: data.avatarId as ChildProfileInput["avatarId"],
  };
}
