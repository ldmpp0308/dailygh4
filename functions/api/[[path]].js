export async function onRequest(context) {
  const { request, params } = context;
  const url = new URL(request.url);
  const path = params.path || "";

  const target = new URL(`https://api.dailygh4.com/api/${path}`);
  target.search = url.search;

  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
  };

  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  // Helper: apply edge caching headers
  function applyEdgeCaching(headers, routePath, method) {
    const h = new Headers(headers);
    const isGet = method === "GET";
    const isLatest = routePath.startsWith("archives/latest");
    const isHistory = routePath.startsWith("archives/history");
    if (isGet && (isLatest || isHistory)) {
      // latest / history CDN 缓存
      const cacheControl = isLatest
        ? "public, max-age=15, s-maxage=300, stale-while-revalidate=120"
        : "public, max-age=60, s-maxage=300, stale-while-revalidate=600";
      h.set("Cache-Control", cacheControl);
      h.set("Vary", "Accept-Encoding");
    } else if (method !== "GET" && method !== "HEAD") {
      // Avoid caching for mutating requests (e.g., upload)
      h.set("Cache-Control", "no-store");
    }
    // Always ensure CORS headers
    Object.entries(corsHeaders).forEach(([k, v]) => h.set(k, v));
    return h;
  }

  // Special route: provide slim version of latest payload
  if (request.method === "GET" && path.startsWith("archives/latest_slim")) {
    try {
      // Edge cache: attempt to serve cached slim response first
      const cache = caches.default;
      const cacheKey = new Request(request.url, request);
      const cached = await cache.match(cacheKey);
      if (cached) {
        // Attach CORS and caching headers on the fly (preserve originals)
        const h = applyEdgeCaching(new Headers(cached.headers), path, "GET");
        return new Response(cached.body, { status: cached.status, headers: h });
      }

      const upstream = new URL(`https://api.dailygh4.com/api/archives/latest`);
      upstream.search = url.search;
      const upstreamResp = await fetch(upstream.toString(), { method: "GET" });
      if (!upstreamResp.ok) {
        // If upstream fails, fall back to any cached copy (even if headers differ)
        if (cached) {
          const h = applyEdgeCaching(new Headers(cached.headers), path, "GET");
          return new Response(cached.body, { status: 200, headers: h });
        }
        const text = await upstreamResp.text();
        return new Response(text || "Upstream error", { status: upstreamResp.status, headers: applyEdgeCaching(new Headers({ "content-type": "text/plain" }), path, "GET") });
      }
      const payload = await upstreamResp.json();
      const memberData = payload?.memberData || {};
      const dates = Object.keys(memberData).sort();
      const latestDate = dates.length ? dates[dates.length - 1] : null;
      const rows = Array.isArray(latestDate ? memberData[latestDate] : []) ? memberData[latestDate] : [];
      // Build slim rows with only essential fields used by UI
      const slimRows = rows.map((r) => ({
        realName: r?.realName ?? r?.姓名 ?? "",
        nickName: r?.nickName ?? r?.nick ?? "",
        fansNum: Number(r?.fansNum ?? r?.粉丝数 ?? 0),
        likeNum: Number(r?.likeNum ?? r?.点赞数 ?? 0),
        collectNum: Number(r?.collectNum ?? r?.收藏数 ?? 0),
        avatarUrl: r?.avatarUrl ?? r?.头像 ?? "",
        birthTs: r?.birthTs ?? null,
        userId: r?.userId ?? null,
        startedDateTime: r?.startedDateTime ?? null,
      }));
      const bodyObj = { date: latestDate, rows: slimRows };
      const bodyStr = JSON.stringify(bodyObj);
      // Compute ETag from SHA-256 of body
      let etag = "";
      try {
        const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(bodyStr));
        const arr = Array.from(new Uint8Array(digest));
        etag = arr.map((b) => b.toString(16).padStart(2, "0")).join("");
      } catch (_) {}
      const headers = applyEdgeCaching(new Headers({ "content-type": "application/json; charset=utf-8" }), path, "GET");
      if (etag) headers.set("ETag", etag);
      const resp = new Response(bodyStr, { status: 200, headers });
      // Put into edge cache for stability (short TTL via headers)
      try { await cache.put(cacheKey, resp.clone()); } catch (_) {}
      return resp;
    } catch (err) {
      return new Response(JSON.stringify({ error: "Slim latest failed", details: String(err) }), {
        status: 500,
        headers: applyEdgeCaching(new Headers({ "content-type": "application/json" }), path, "GET"),
      });
    }
  }

  const method = request.method;
  const headers = new Headers();
  const contentType = request.headers.get("content-type");
  if (contentType) headers.set("content-type", contentType);
  const authorization = request.headers.get("authorization");
  if (authorization) headers.set("authorization", authorization);

  // Stream request instead of buffering entire body
  const init = { method, headers };
  if (method !== "GET" && method !== "HEAD") {
    init.body = request.body;
  }

  let upstreamResp;
  try {
    // For GET latest/history, apply edge cache to reduce snapshot toggling
    const isGet = method === "GET";
    const isLatest = path.startsWith("archives/latest");
    const isHistory = path.startsWith("archives/history");
    if (isGet && (isLatest || isHistory)) {
      const cache = caches.default;
      const cacheKey = new Request(request.url, request);
      const cached = await cache.match(cacheKey);
      if (cached) {
        const h = applyEdgeCaching(new Headers(cached.headers), path, method);
        return new Response(cached.body, { status: cached.status, headers: h });
      }
      upstreamResp = await fetch(target.toString(), init);
      let respHeaders = new Headers(upstreamResp.headers);
      respHeaders = applyEdgeCaching(respHeaders, path, method);
      const streamResp = new Response(upstreamResp.body, { status: upstreamResp.status, headers: respHeaders });
      try { await cache.put(cacheKey, streamResp.clone()); } catch (_) {}
      return streamResp;
    }
    upstreamResp = await fetch(target.toString(), init);
  } catch (err) {
    const errHeaders = applyEdgeCaching(new Headers({ "content-type": "application/json" }), path, method);
    return new Response(JSON.stringify({ error: "Upstream fetch failed", details: String(err) }), {
      status: 502,
      headers: errHeaders,
    });
  }

  let respHeaders = new Headers(upstreamResp.headers);
  respHeaders = applyEdgeCaching(respHeaders, path, method);

  // Stream response back to client
  return new Response(upstreamResp.body, { status: upstreamResp.status, headers: respHeaders });
}