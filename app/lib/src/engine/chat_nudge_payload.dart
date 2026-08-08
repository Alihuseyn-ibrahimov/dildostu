/// Chat bildiriş payload konvensiyası — söz paketlərindən (`pack_id`) ayrılır.
const chatPayloadPrefix = 'chat|';

String encodeChatNudgePayload(String quickPrompt) =>
    '$chatPayloadPrefix${Uri.encodeComponent(quickPrompt)}';

bool isChatNudgePayload(String? payload) =>
    payload != null && payload.startsWith(chatPayloadPrefix);

String? decodeChatNudgePrompt(String payload) {
  if (!payload.startsWith(chatPayloadPrefix)) return null;
  if (payload.length <= chatPayloadPrefix.length) return null;
  return Uri.decodeComponent(payload.substring(chatPayloadPrefix.length));
}
