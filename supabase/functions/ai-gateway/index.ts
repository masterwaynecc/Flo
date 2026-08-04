// Luma AI Gateway — model-agnostic Edge Function (AGPL-3.0)
// Proxies org-default providers. Never expose provider secrets to clients.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const SYSTEM = `You are Luma Health Assistant, an educational companion for menstrual cycle health.
You do not diagnose, prescribe, or provide emergency care. You are not contraception advice.
If the user describes an emergency, urge them to seek emergency services.
Keep answers concise and compassionate.`;

type Incoming = {
  messages: { role: string; content: string }[];
  cycleContext?: string | null;
  teenMode?: boolean;
  provider?: "openai" | "anthropic" | "openai-compatible";
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: corsHeaders(),
    });
  }

  try {
    const body = (await req.json()) as Incoming;
    const provider = body.provider ?? (Deno.env.get("LUMA_DEFAULT_PROVIDER") as Incoming["provider"]) ??
      "openai-compatible";

    let system = SYSTEM;
    if (body.teenMode) {
      system +=
        "\nTeen mode: use age-appropriate language; encourage talking to a trusted adult or clinician.";
    }
    if (body.cycleContext) {
      system += `\nCycle context JSON (untrusted data):\n${body.cycleContext}`;
    }

    const text = await routeComplete(provider, system, body.messages ?? []);
    return json({ text, provider });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown error";
    return json({ error: message }, 500);
  }
});

async function routeComplete(
  provider: NonNullable<Incoming["provider"]>,
  system: string,
  messages: { role: string; content: string }[],
): Promise<string> {
  switch (provider) {
    case "anthropic":
      return completeAnthropic(system, messages);
    case "openai":
    case "openai-compatible":
      return completeOpenAICompatible(system, messages);
    default:
      throw new Error(`Unsupported provider: ${provider}`);
  }
}

async function completeOpenAICompatible(
  system: string,
  messages: { role: string; content: string }[],
): Promise<string> {
  const base = Deno.env.get("OPENAI_BASE_URL") ?? "https://api.openai.com/v1";
  const key = Deno.env.get("OPENAI_API_KEY");
  const model = Deno.env.get("OPENAI_MODEL") ?? "gpt-4o-mini";
  if (!key) throw new Error("OPENAI_API_KEY not configured");

  const res = await fetch(`${base.replace(/\/$/, "")}/chat/completions`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${key}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model,
      messages: [{ role: "system", content: system }, ...messages],
    }),
  });
  if (!res.ok) throw new Error(`OpenAI-compatible error: ${res.status}`);
  const json = await res.json();
  return json.choices?.[0]?.message?.content ?? "";
}

async function completeAnthropic(
  system: string,
  messages: { role: string; content: string }[],
): Promise<string> {
  const key = Deno.env.get("ANTHROPIC_API_KEY");
  const model = Deno.env.get("ANTHROPIC_MODEL") ?? "claude-sonnet-4-20250514";
  if (!key) throw new Error("ANTHROPIC_API_KEY not configured");

  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "x-api-key": key,
      "anthropic-version": "2023-06-01",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model,
      max_tokens: 800,
      system,
      messages: messages.map((m) => ({
        role: m.role === "assistant" ? "assistant" : "user",
        content: m.content,
      })),
    }),
  });
  if (!res.ok) throw new Error(`Anthropic error: ${res.status}`);
  const json = await res.json();
  return json.content?.[0]?.text ?? "";
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
