/**
 * flow-us 工作台云同步后端（Cloudflare Worker + KV）
 *
 * 接口：
 *   GET  /state?code=<同步码>   拉取快照
 *   PUT  /state?code=<同步码>   写入快照（全量覆盖，前端保证是完整数据）
 *
 * 同步码只用于隔离不同人的数据，经 SHA-256 后作为 KV key，不明文落盘。
 */

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET,PUT,OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
  "Access-Control-Max-Age": "86400"
};

const MAX_BYTES = 1024 * 1024; // 1MB，KV 单值上限内留足余量

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === "OPTIONS") return new Response(null, { headers: CORS });

    // 兼容两种部署形态：独立子域（/state）与 Pages 同源反代（/api/state）
    if (!url.pathname.endsWith("/state")) return json({ error: "not found" }, 404);

    const code = (url.searchParams.get("code") || "").trim();
    if (code.length < 4) return json({ error: "code too short" }, 400);

    if (!env.FOCUS_KV) return json({ error: "KV not bound" }, 500);

    const key = "state:" + (await sha256(code));

    if (request.method === "GET") {
      const raw = await env.FOCUS_KV.get(key);
      if (!raw) return json({ data: null }, 200);
      try {
        return json({ data: JSON.parse(raw) }, 200);
      } catch (e) {
        return json({ error: "stored data corrupted" }, 500);
      }
    }

    if (request.method === "PUT") {
      let body;
      try {
        body = await request.json();
      } catch (e) {
        return json({ error: "bad json" }, 400);
      }
      if (!body || typeof body !== "object") return json({ error: "bad payload" }, 400);

      const payload = JSON.stringify(body);
      if (payload.length > MAX_BYTES) return json({ error: "payload too large" }, 413);

      await env.FOCUS_KV.put(key, payload);
      return json({ ok: true, updatedAt: body.updatedAt || Date.now() }, 200);
    }

    return json({ error: "method not allowed" }, 405);
  }
};

function json(obj, status) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: Object.assign({ "Content-Type": "application/json; charset=utf-8" }, CORS)
  });
}

async function sha256(str) {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(str));
  return Array.from(new Uint8Array(buf))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("")
    .slice(0, 32);
}
