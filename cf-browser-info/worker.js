export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const cf = request.cf ? { ...request.cf } : {};

    const headers = {};
    for (const [key, value] of request.headers.entries()) {
      headers[key] = value;
    }

    const ip = request.headers.get("cf-connecting-ip") ||
               request.headers.get("x-forwarded-for") ||
               null;
    const ipv6 = request.headers.get("cf-connecting-ipv6") || null;

    const wantJson = url.pathname === "/json" || url.searchParams.has("json");

    if (wantJson) {
      const info = {
        ip,
        ipv6,
        method: request.method,
        url: request.url,
        path: url.pathname,
        query: Object.fromEntries(url.searchParams.entries()),
        protocol: url.protocol.replace(":", ""),
        host: url.hostname,
        port: url.port || null,
        headers,
        cf: {
          asn: cf.asn ?? null,
          asOrganization: cf.asOrganization ?? null,
          city: cf.city ?? null,
          continent: cf.continent ?? null,
          country: cf.country ?? null,
          latitude: cf.latitude ?? null,
          longitude: cf.longitude ?? null,
          postalCode: cf.postalCode ?? null,
          region: cf.region ?? null,
          regionCode: cf.regionCode ?? null,
          timezone: cf.timezone ?? null,
          datacenter: cf.colo ?? null,
          httpProtocol: cf.httpProtocol ?? null,
          tlsVersion: cf.tlsVersion ?? null,
          tlsCipher: cf.tlsCipher ?? null,
          tlsClientAuth: cf.tlsClientAuth ?? null,
          botManagement: cf.botManagement ?? null,
          isEUCountry: cf.isEUCountry ?? null,
          requestPriority: cf.requestPriority ?? null,
        },
      };
      return new Response(JSON.stringify(info, null, 2), {
        headers: {
          "content-type": "application/json;charset=UTF-8",
          "access-control-allow-origin": "*",
        },
      });
    }

    // Terse text response
    const lines = [
      `IP:         ${ip || ipv6 || "unknown"}`,
      `Host:       ${url.hostname}`,
      `Protocol:   ${cf.httpProtocol ?? url.protocol.replace(":", "").toUpperCase()}`,
      `TLS:        ${cf.tlsVersion ?? "none"} / ${cf.tlsCipher ?? "n/a"}`,
      `Datacenter: ${cf.colo ?? "unknown"}`,
      `ASN:        ${cf.asn ?? "unknown"} (${cf.asOrganization ?? "unknown"})`,
      `Location:   ${[cf.city, cf.region, cf.country].filter(Boolean).join(", ") || "unknown"}`,
      `Timezone:   ${cf.timezone ?? "unknown"}`,
      `Coords:     ${cf.latitude ?? "?"}, ${cf.longitude ?? "?"}`,
      `Bot score:  ${cf.botManagement?.score ?? "n/a"} (verified: ${cf.botManagement?.verifiedBot ?? "n/a"})`,
      ``,
      `Headers:`,
      ...Object.entries(headers).map(([k, v]) => `  ${k}: ${v}`),
      ``,
      `Add ?json for full JSON output.`,
    ];

    return new Response(lines.join("\n"), {
      headers: {
        "content-type": "text/plain;charset=UTF-8",
        "access-control-allow-origin": "*",
      },
    });
  },
};
