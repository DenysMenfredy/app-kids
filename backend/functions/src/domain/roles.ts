/**
 * Roles (spec §14). Assigned exclusively server-side via Firebase custom
 * claims — the client can never self-assign a role.
 */
export type Role = "parent" | "content_editor" | "admin";

export const ALL_ROLES: readonly Role[] = ["parent", "content_editor", "admin"];

export function isRole(value: unknown): value is Role {
  return typeof value === "string" && (ALL_ROLES as string[]).includes(value);
}
