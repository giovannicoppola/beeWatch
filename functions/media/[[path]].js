// Pages serves static files whole and ignores Range, but Safari plays a video only if it can
// fetch it in parts, and a chapter jump needs that too. So files under /media/ come through
// here: the whole file from the static assets, then the requested slice of it.
export async function onRequestGet({ request, env }) {
  const response = await env.ASSETS.fetch(request.url);
  if (!response.ok) return response;
  const headers = new Headers(response.headers);
  headers.set('Accept-Ranges', 'bytes');
  const range = /^bytes=(\d*)-(\d*)$/.exec(request.headers.get('Range') ?? '');
  if (!range) return new Response(response.body, { status: response.status, headers });
  const body = await response.arrayBuffer();
  const size = body.byteLength;
  const [, first, last] = range;
  const start = first ? Number(first) : Math.max(0, size - Number(last || 0));
  const end = first && last ? Math.min(Number(last), size - 1) : size - 1;
  if (start > end || start >= size) return new Response(null, { status: 416, headers: { 'Content-Range': `bytes */${size}` } });
  headers.set('Content-Range', `bytes ${start}-${end}/${size}`);
  headers.delete('Content-Length');
  return new Response(body.slice(start, end + 1), { status: 206, headers });
}
