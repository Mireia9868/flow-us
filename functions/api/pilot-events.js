const events = new Set([
  "app_opened", "task_created", "focus_started",
  "focus_qualified", "task_result_saved", "task_completed"
]);
const cohorts = new Set(["growth", "qa"]);
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export async function onRequest({ request, env }) {
  if (request.method !== "POST") {
    return new Response(null, { status: 405, headers: { Allow: "POST" } });
  }
  const origin = request.headers.get("Origin");
  const sameOrigin = origin === new URL(request.url).origin ||
    (!origin && request.headers.get("Sec-Fetch-Site") === "same-origin");
  if (!sameOrigin) {
    return new Response(null, { status: 403 });
  }
  if (!env.PILOT_DB) return new Response(null, { status: 503 });

  const reader = request.body?.getReader();
  if (!reader) return new Response(null, { status: 400 });
  const decoder = new TextDecoder();
  let payload = "";
  let size = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    size += value.byteLength;
    if (size > 512) {
      await reader.cancel();
      return new Response(null, { status: 413 });
    }
    payload += decoder.decode(value, { stream: true });
  }

  let data;
  try {
    data = JSON.parse(payload + decoder.decode());
  } catch {
    return new Response(null, { status: 400 });
  }
  if (!data || Object.keys(data).length !== 4 ||
      !events.has(data.event) || !cohorts.has(data.cohort) ||
      typeof data.eventId !== "string" || !uuid.test(data.eventId) ||
      typeof data.visitorId !== "string" || !uuid.test(data.visitorId)) {
    return new Response(null, { status: 400 });
  }

  await env.PILOT_DB.prepare(
    "INSERT OR IGNORE INTO pilot_events (event_id, visitor_id, cohort, event) VALUES (?, ?, ?, ?)"
  ).bind(data.eventId, data.visitorId, data.cohort, data.event).run();
  return new Response(null, { status: 204 });
}
