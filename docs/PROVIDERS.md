# Provider compatibility

PackWrite uses Kujo's OpenAI-compatible `ai_chat` contract: Bearer authentication,
`{model, messages}` requests, and `choices[0].message.content` responses. This table
describes protocol compatibility, not live-provider certification; the default test
suite is intentionally offline.

| Provider or gateway | Endpoint form | PackWrite status | Notes |
| --- | --- | --- | --- |
| DeepSeek | `https://api.deepseek.com/chat/completions` | Built-in preset; offline contract tested | Adds JSON response mode and disables thinking for pack generation. |
| OpenAI | `https://api.openai.com/v1/chat/completions` | Built-in preset; offline contract tested | Uses `OPENAI_API_KEY` or `PACKWRITE_API_KEY`. |
| Local OpenAI-compatible server | `http://localhost:11434/v1/chat/completions` | Built-in preset; offline contract tested | The server must accept the OpenAI chat-completions shape. |
| OpenRouter | Provider's OpenAI-compatible chat-completions URL | Explicit `--endpoint`; protocol-compatible, not live-certified | Set the gateway's model identifier and use `PACKWRITE_API_KEY`. |
| LiteLLM | Deployment's `/v1/chat/completions` URL | Explicit `--endpoint`; protocol-compatible, not live-certified | Authentication and model routing are deployment-specific. |
| Anthropic native API | `/v1/messages` | Not supported natively | Route through an OpenAI-compatible gateway and pass its URL explicitly. |
| Gemini/Google native API | Native generate-content endpoint | Not supported natively | Route through an OpenAI-compatible gateway and pass its URL explicitly. |

PackWrite validates that explicit endpoints use plain `http://` or `https://`, contain
no embedded credentials, and contain no line controls. Put API keys only in environment
variables. Before relying on a gateway in automation, run `packwrite doctor --strict`
and a controlled smoke generation with non-sensitive input.

Provider/network retries remain deliberately single-shot: the current Kujo adapter
does not expose a stable, sanitized status classification that lets PackWrite
distinguish retryable transport/5xx failures from authentication or other 4xx failures.
Blind retries could duplicate expensive requests. Add retries only after that runtime
contract exists and is covered by deterministic tests.
