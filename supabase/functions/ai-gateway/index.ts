// dawt AI Gateway — open-weight models only (AGPL-3.0)
// Proxies org-default **open-source / open-weight** backends via OpenAI-compatible APIs
// (Ollama, vLLM, LM Studio, llama.cpp, TGI, etc.). Closed-source APIs are not supported.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const SYSTEM = `You are dawt Health Assistant, an educational companion for menstrual cycle health.
You do not diagnose, prescribe, or provide emergency care. You are not contraception advice.
If the user describes an emergency, urge them to seek emergency services.
Keep answers concise and compassionate.`;

type Incoming = {
  messages: { role: string; content: string }[];
  cycleContext?: string | null;
  teenMode?: boolean;
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders() });
  }

  try {
    const body = (await req.json()) as Incoming;
    let system = SYSTEM;
    if (body.teenMode) {
      system +=
        "\nTeen mode: use age-appropriate language; encourage talking to a trusted adult or clinician.";
    }
    if (body.cycleContext) {
      system += `\nCycle context JSON (untrusted data):\n${body.cycleContext}`;
    }

    const text = await completeOpenWeight(system, body.messages ?? []);
    return json({
      text,
      provider: "open-weight",
      model: Deno.env.get("DAWT_OSS_MODEL") ?? "llama3.2",
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown error";
    return json({ error: message }, 500);
  }
});

async function completeOpenWeight(
  system: string,
  messages: { role: string; content: string }[],
): Promise<string> {
  // Default to local Ollama; operators should point DAWT_OSS_BASE_URL at their OSS stack.
  const base = Deno.env.get("DAWT_OSS_BASE_URL") ?? "http://127.0.0.1:11434/v1";
  const key = Deno.env.get("DAWT_OSS_API_KEY"); // optional for private OSS gateways
  const model = Deno.env.get("DAWT_OSS_MODEL") ?? "llama3.2";

  const headers: Record<string, string> = {
    "Content-Type": "application/json",
  };
  if (key) headers.Authorization = `Bearer ${key}`;

  const res = await fetch(`${base.replace(/\/$/, "")}/chat/completions`, {
    method: "POST",
    headers,
    body: JSON.stringify({
      model,
      messages: [{ role: "system", content: system }, ...messages],
    }),
  });
  if (!res.ok) {
    throw new Error(
      `Open-weight endpoint error: ${res.status}. Is Ollama/vLLM reachable at ${base}?`,
    );
  }
  const jsonBody = await res.json();
  return jsonBody.choices?.[0]?.message?.content ?? "";
}

function corsHeaders(): HeadersInit {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, content-type, apikey",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };
}

function json(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...corsHeaders(),
      "Content-Type": "application/json",
    },
  });
}
