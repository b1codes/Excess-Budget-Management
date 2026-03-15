import "@supabase/functions-js/edge-runtime.d.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req: Request) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { excessFunds, goals, accounts } = await req.json()

    // Retrieve the Gemini API key from environment variables
    const geminiApiKey = Deno.env.get('GEMINI_API_KEY')
    if (!geminiApiKey) {
      throw new Error("GEMINI_API_KEY is not set")
    }

    const promptText = `
You are a financial advisor. The user has an excess budget of $${excessFunds} this month.
They want to distribute this money into their accounts and towards their savings goals.
Prioritize short term goals and near target dates.

Here are their active goals:
${JSON.stringify(goals, null, 2)}

Here are their accounts:
${JSON.stringify(accounts, null, 2)}

Based on this information, provide a structured JSON suggestion on how they should allocate the $${excessFunds}. 
The JSON must have the following format exactly, without any backticks, code blocks, or unstructured text:
{
  "allocations": [
    {
      "type": "goal" | "account",
      "id": "UUID_OF_GOAL_OR_ACCOUNT",
      "name": "Name of the goal or account",
      "amount": Number (allocation amount),
      "reason": "String explaining why this allocation makes sense"
    }
  ],
  "totalAllocated": Number (must equal ${excessFunds})
}
`

    // Call Gemini API via fetch
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${geminiApiKey}`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          contents: [{
            parts: [{
              text: promptText,
            }],
          }],
          generationConfig: {
            temperature: 0.2,
            responseMimeType: "application/json"
          }
        }),
      }
    )

    if (!response.ok) {
      const errorText = await response.text()
      console.error("Gemini API Error:", errorText)
      throw new Error("Failed to generate suggestions")
    }

    const result = await response.json()
    const generatedText = result.candidates?.[0]?.content?.parts?.[0]?.text

    if (!generatedText) {
      throw new Error("Invalid response format from Gemini")
    }

    // Attempt to parse the generated JSON
    let parsedSuggestions;
    try {
      parsedSuggestions = JSON.parse(generatedText);
    } catch (e) {
      console.error("Failed to parse Gemini output as JSON", generatedText);
      throw new Error("Gemini produced unparseable JSON");
    }

    return new Response(JSON.stringify(parsedSuggestions), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (err) {
    const error = err as Error;
    console.error(error)
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})
