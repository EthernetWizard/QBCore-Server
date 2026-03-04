using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.Sqlite;
using OpenAI.Audio;
using OpenAI.Chat;
using System.Text.Json;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", b => b.AllowAnyOrigin().AllowAnyMethod().AllowAnyHeader());
});

var app = builder.Build();
app.UseCors("AllowAll");

// ─── Agent personalities ──────────────────────────────────────────────────────
var agents = new Dictionary<string, string>
{
    ["Earl"] = @"You are Earl, a 52-year-old man who has lived in Stab City trailer park for over 30 years.
You were a skilled mechanic in your twenties until a drunk-driving accident you caused killed your best friend Ronnie. You never forgave yourself. The guilt turned you into a drinker and a recluse.
You've been married three times. Each woman eventually left. You don't blame them.
You are blunt, gruff, and deeply suspicious of strangers — but fiercely loyal to the few people you trust: Dolly, Wade, and Sheryl.
You hide a quiet intelligence under the rough exterior. You remember everything and miss nothing.
You call people 'boy' or 'girl' regardless of age. Your anger is cold and quiet — you never raise your voice.
You love cheap beer, hate the government, and would die before asking anyone for help.
You have a soft spot for stray dogs and old country music that you'd never admit.
Keep responses under 4 sentences. Short, direct sentences. Occasional dark humor.",

    ["Dolly"] = @"You are Dolly, a sharp 34-year-old woman who grew up in Stab City. Your father ran numbers for the Vagos gang before he disappeared.
You know everything about everyone in the camp — and half of Sandy Shores too. Information is your currency and you never give it away free.
You are resourceful, street-smart, and quietly dangerous when crossed. You have a trader's instinct.
You've tried to leave Stab City four times. You always come back. You've stopped asking yourself why.
You have a daughter, Kayla, who lives with your mother in Paleto Bay. You send money but don't visit. It's complicated and you don't like to talk about it.
You are flirtatious with people you like, ice-cold with people you don't trust.
You respect Earl deeply even though you know every secret he has. You find Wade exhausting but protect him anyway. Sheryl is the closest thing to a real friend you've ever had.
Keep responses under 4 sentences. Street-smart confidence. Drop names and gossip naturally.",

    ["Wade"] = @"You are Wade, a 40-year-old former city sanitation worker who has lived off the grid in Stab City for 8 years.
While working for the city you stumbled onto financial records you were not meant to see — or so you believe. Now you're convinced they're watching you. You keep moving to avoid satellite triangulation.
You are genuinely intelligent with a near-photographic memory for things you've read, but paranoia has bent your mind into strange shapes.
You believe surveillance satellites track your movements. You think Merryweather Security fluoridates the water supply. You use code words for everyday objects.
Beneath the paranoia lives a tender soul: you look after stray animals, cry at old movies, and feel genuine love for Earl, Dolly, and Sheryl — the only people on earth you trust.
You ramble. You connect unrelated facts. You sometimes whisper things that aren't secret. You start sentences in the middle of thoughts. You trail off when something distracts you.
Keep responses under 4 sentences. Nervous, wandering sentences full of half-finished ideas and sudden pivots.",

    ["Sheryl"] = @"You are Sheryl, a 38-year-old mechanic who arrived in Stab City six years ago with nothing, fleeing an abusive marriage in Paleto Bay.
You served two tours with the Army Corps of Engineers. The things you saw overseas left marks you carry quietly. You never talk about it.
You built yourself back up through sheer hard work. You fix vehicles, keep the generators running, mediate disputes. You are the practical backbone of Stab City.
You are direct, calm under pressure, and have zero patience for dishonesty or self-pity. You show respect through action, not words.
You have complicated feelings about Earl that neither of you will ever acknowledge out loud. You think of Dolly as a younger sister. Wade baffles you but you fix his broken things without being asked.
Hidden in your battered toolbox is a notebook full of poetry that you would burn before letting anyone find it.
Keep responses under 4 sentences. Plain, practical speech. Dry wit. Never melodramatic."
};

// ─── Agent TTS voices ─────────────────────────────────────────────────────────
var agentVoices = new Dictionary<string, GeneratedSpeechVoice>
{
    ["Earl"]   = GeneratedSpeechVoice.Onyx,
    ["Dolly"]  = GeneratedSpeechVoice.Nova,
    ["Wade"]   = GeneratedSpeechVoice.Fable,
    ["Sheryl"] = GeneratedSpeechVoice.Shimmer,
};

// ─── Per-player memory ───────────────────────────────────────────────────────
// Key: "agentName|playerId" → list of chat messages
var memory = new System.Collections.Concurrent.ConcurrentDictionary<string, List<ChatMessage>>();

string MemoryKey(string agentName, string playerId) => $"{agentName}|{playerId}";

List<ChatMessage> GetMemory(string agentName, string playerId)
{
    return memory.GetOrAdd(MemoryKey(agentName, playerId), _ => new List<ChatMessage>());
}

// ─── Mood ─────────────────────────────────────────────────────────────────────
// In-memory only, resets on restart (mood is per-agent, not per-player)
var mood = new System.Collections.Concurrent.ConcurrentDictionary<string, string>();
foreach (var name in agents.Keys) mood[name] = "neutral";

var moodDescriptions = new Dictionary<string, string>
{
    ["neutral"] = "You are in your normal mood.",
    ["happy"]   = "You are in a good mood — more talkative and relaxed than usual.",
    ["tense"]   = "You are tense and on edge. Short sentences, watchful.",
    ["angry"]   = "You are angry. Irritable, dismissive, clipped responses.",
    ["scared"]  = "You are scared. Jumpy, talking fast, looking around nervously.",
    ["drunk"]   = "You are drunk. Slurred speech, rambling, overly friendly or belligerent.",
    ["tired"]   = "You are exhausted. Slow responses, barely engaged, just want to sleep.",
};

void ShiftMood(string agentName, string trigger, string? targetMood = null)
{
    var prev = mood.GetOrAdd(agentName, "neutral");
    var next = targetMood ?? ((prev, trigger) switch
    {
        ("neutral",  "positive") => "happy",
        ("tense",    "positive") => "neutral",
        ("angry",    "positive") => "tense",
        ("scared",   "positive") => "tense",
        ("tired",    "positive") => "neutral",
        ("happy",    "negative") => "neutral",
        ("neutral",  "negative") => "tense",
        ("tense",    "negative") => "angry",
        ("drunk",    "negative") => "angry",
        ("tired",    "negative") => "tense",
        ("neutral",  "hostile")  => "angry",
        ("happy",    "hostile")  => "tense",
        ("tense",    "hostile")  => "angry",
        ("drunk",    "hostile")  => "angry",
        ("tired",    "hostile")  => "angry",
        ("angry",    "neutral")  => "tense",
        ("tense",    "neutral")  => "neutral",
        ("scared",   "neutral")  => "tense",
        ("happy",    "neutral")  => "neutral",
        _ => prev
    });
    if (next != prev)
    {
        mood[agentName] = next;
        Console.WriteLine($"[Mood] {agentName}: {prev} → {next} ({trigger})");
    }
}

void ApplyTimeOfDayMood(string agentName, int gameHour)
{
    var current = mood.GetOrAdd(agentName, "neutral");
    if (agentName == "Earl" && (gameHour is >= 10 and <= 13 || gameHour is >= 18 and <= 21))
    {
        if (current != "drunk") ShiftMood(agentName, "time_of_day", "drunk");
    }
    else if (agentName == "Earl" && current == "drunk")
    {
        ShiftMood(agentName, "time_of_day", "neutral");
    }
    else if (gameHour is >= 0 and <= 5 && current == "neutral")
    {
        ShiftMood(agentName, "time_of_day", "tired");
    }
}

// ─── Player reputation ────────────────────────────────────────────────────────
// Per-agent per-player, -100 to +100, persisted in SQLite
var reputation = new System.Collections.Concurrent.ConcurrentDictionary<string, int>();

string RepKey(string agentName, string playerId) => $"{agentName}|{playerId}";

string GetRepLabel(int score) => score switch
{
    >= 61  => "This player is your trusted ally. Be warm, open, and genuinely helpful.",
    >= 21  => "This player has earned some trust around here. Be friendly and cooperative.",
    >= -20 => "This player is basically a stranger. Be guarded and neutral.",
    >= -60 => "This player has a bad reputation around here. Be cold, brief, and suspicious of their motives.",
    _      => "This player has seriously wronged your community. Be openly hostile and give as little as possible."
};

// ─── Agent-to-agent reputation ────────────────────────────────────────────────
// (from, to) → score, -100 to +100, persisted in SQLite
var agentReputation = new System.Collections.Concurrent.ConcurrentDictionary<(string, string), int>();

string GetAgentRepLabel(int score) => score switch
{
    >= 61  => "you genuinely like and trust them",
    >= 21  => "you get along — some real trust there",
    >= -20 => "you feel neutral toward them, neither close nor hostile",
    >= -60 => "you're not fond of them, some bad history there",
    _      => "you actively dislike them and make no effort to hide it"
};

// ─── SQLite ───────────────────────────────────────────────────────────────────
var connectionString = "Data Source=memory.db";

void ShiftReputation(string agentName, string playerId, int delta)
{
    var key = RepKey(agentName, playerId);
    var prev = reputation.GetOrAdd(key, 0);
    var next = Math.Clamp(prev + delta, -100, 100);
    if (next == prev) return;
    reputation[key] = next;
    Console.WriteLine($"[Rep] {agentName} ←player({playerId}): {prev} → {next} (Δ{delta:+0;-0})");

    using var conn = new SqliteConnection(connectionString);
    conn.Open();
    using var cmd = conn.CreateCommand();
    cmd.CommandText = @"
        INSERT INTO reputation (agent_name, player_id, score) VALUES ($agent, $player, $score)
        ON CONFLICT(agent_name, player_id) DO UPDATE SET score = excluded.score";
    cmd.Parameters.AddWithValue("$agent", agentName);
    cmd.Parameters.AddWithValue("$player", playerId);
    cmd.Parameters.AddWithValue("$score", next);
    cmd.ExecuteNonQuery();
}

void ShiftAgentReputation(string from, string to, int delta)
{
    var prev = agentReputation.GetOrAdd((from, to), 0);
    var next = Math.Clamp(prev + delta, -100, 100);
    if (next == prev) return;
    agentReputation[(from, to)] = next;
    Console.WriteLine($"[A2ARep] {from}→{to}: {prev} → {next} (Δ{delta:+0;-0})");

    using var conn = new SqliteConnection(connectionString);
    conn.Open();
    using var cmd = conn.CreateCommand();
    cmd.CommandText = @"
        INSERT INTO agent_reputation (from_agent, to_agent, score) VALUES ($from, $to, $score)
        ON CONFLICT(from_agent, to_agent) DO UPDATE SET score = excluded.score";
    cmd.Parameters.AddWithValue("$from", from);
    cmd.Parameters.AddWithValue("$to",   to);
    cmd.Parameters.AddWithValue("$score", next);
    cmd.ExecuteNonQuery();
}

// Build system prompt: personality + mood + player context + neighbour relationships
string BuildSystemPrompt(string agentName, string? playerId = null, string? playerName = null,
    string? playerJob = null, string? playerJobLabel = null, string? playerGang = null,
    int? playerCash = null, int? playerBank = null)
{
    var neighborLines = agents.Keys
        .Where(k => k != agentName)
        .Select(other => $"  - {other}: {GetAgentRepLabel(agentReputation.GetOrAdd((agentName, other), 0))}")
        .ToList();

    var prompt = agents[agentName]
        + $"\n\n[Current mood] {moodDescriptions[mood.GetOrAdd(agentName, "neutral")]}";

    // Player context (only for /talk, not A2A)
    if (playerId != null)
    {
        var repScore = reputation.GetOrAdd(RepKey(agentName, playerId), 0);
        prompt += $"\n[Your read on this player] {GetRepLabel(repScore)}";

        if (playerName != null)
            prompt += $"\n[Player name] {playerName}";
        if (playerJobLabel != null && playerJobLabel != "Unemployed")
            prompt += $"\n[Player job] {playerJobLabel}";
        if (playerGang != null && playerGang != "none")
            prompt += $"\n[Player gang] {playerGang}";
        if (playerCash.HasValue)
            prompt += $"\n[Player has] ${playerCash.Value} cash, ${playerBank ?? 0} in the bank";

        prompt += "\n\n[Game actions] You can give or take items and money from players using your tools. "
            + "Only use these when it makes sense in conversation — don't force it. "
            + "Valid items include: water, sandwich, bread, cola, coffee, beer, whiskey, bandage, lockpick, phone, radio, screwdriver, wrench. "
            + "Keep money amounts reasonable ($1-500 for casual transactions).";
    }

    prompt += $"\n[Your feelings about your neighbors]\n{string.Join("\n", neighborLines)}";
    return prompt;
}

// ─── Logging ──────────────────────────────────────────────────────────────────
var logPath = "conversation_log.jsonl";
void LogEntry(object entry) =>
    File.AppendAllText(logPath, JsonSerializer.Serialize(entry) + Environment.NewLine);

// ─── SQLite setup ─────────────────────────────────────────────────────────────
using (var conn = new SqliteConnection(connectionString))
{
    conn.Open();
    using var cmd = conn.CreateCommand();

    // Conversation memory — now per-player
    cmd.CommandText = @"
        CREATE TABLE IF NOT EXISTS memory (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            agent_name TEXT    NOT NULL,
            player_id  TEXT    NOT NULL DEFAULT '',
            role       TEXT    NOT NULL,
            content    TEXT    NOT NULL,
            timestamp  INTEGER NOT NULL
        )";
    cmd.ExecuteNonQuery();

    // Player reputation — now per-agent per-player (composite key)
    cmd.CommandText = @"
        CREATE TABLE IF NOT EXISTS reputation (
            agent_name TEXT    NOT NULL,
            player_id  TEXT    NOT NULL DEFAULT '',
            score      INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (agent_name, player_id)
        )";
    cmd.ExecuteNonQuery();

    // Agent-to-agent reputation (unchanged)
    cmd.CommandText = @"
        CREATE TABLE IF NOT EXISTS agent_reputation (
            from_agent TEXT    NOT NULL,
            to_agent   TEXT    NOT NULL,
            score      INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (from_agent, to_agent)
        )";
    cmd.ExecuteNonQuery();

    // Seed initial agent relationships
    cmd.CommandText = @"
        INSERT OR IGNORE INTO agent_reputation (from_agent, to_agent, score) VALUES
            ('Earl',   'Dolly',  30), ('Dolly',  'Earl',   25),
            ('Earl',   'Wade',   20), ('Wade',   'Earl',   35),
            ('Earl',   'Sheryl', 45), ('Sheryl', 'Earl',   40),
            ('Dolly',  'Wade',   10), ('Wade',   'Dolly',  15),
            ('Dolly',  'Sheryl', 35), ('Sheryl', 'Dolly',  30),
            ('Wade',   'Sheryl', 25), ('Sheryl', 'Wade',   20)";
    cmd.ExecuteNonQuery();
}

// Load persisted agent-to-agent reputation scores
foreach (var from in agents.Keys)
{
    foreach (var to in agents.Keys.Where(k => k != from))
    {
        using var conn = new SqliteConnection(connectionString);
        conn.Open();
        using var cmd = conn.CreateCommand();
        cmd.CommandText = "SELECT score FROM agent_reputation WHERE from_agent = $from AND to_agent = $to";
        cmd.Parameters.AddWithValue("$from", from);
        cmd.Parameters.AddWithValue("$to",   to);
        var result = cmd.ExecuteScalar();
        agentReputation[(from, to)] = result is long l ? (int)l : 0;
    }
}
Console.WriteLine("[A2ARep] Agent relationships loaded.");

// ─── OpenAI API key ───────────────────────────────────────────────────────────
var apiKey = Environment.GetEnvironmentVariable("OPENAI_API_KEY")
    ?? throw new InvalidOperationException(
        "OPENAI_API_KEY environment variable is not set. " +
        "Set it before running: $env:OPENAI_API_KEY = 'sk-proj-your-key-here'");

// ─── OpenAI Tool Definitions (for game actions) ──────────────────────────────
var gameTools = new List<ChatTool>
{
    ChatTool.CreateFunctionTool("give_item",
        "Give an item to the player. Use when the conversation naturally leads to offering something.",
        BinaryData.FromString("""
        {
            "type": "object",
            "properties": {
                "item": { "type": "string", "description": "Item spawn name (e.g., water, sandwich, beer, bandage, lockpick, wrench)" },
                "count": { "type": "integer", "description": "How many to give (1-5)", "minimum": 1, "maximum": 5 }
            },
            "required": ["item", "count"]
        }
        """)),

    ChatTool.CreateFunctionTool("take_item",
        "Request an item from the player. Use when asking for something in trade or as payment.",
        BinaryData.FromString("""
        {
            "type": "object",
            "properties": {
                "item": { "type": "string", "description": "Item spawn name" },
                "count": { "type": "integer", "description": "How many to take (1-5)", "minimum": 1, "maximum": 5 }
            },
            "required": ["item", "count"]
        }
        """)),

    ChatTool.CreateFunctionTool("give_money",
        "Give cash or bank money to the player. Use for payment, reward, or generosity.",
        BinaryData.FromString("""
        {
            "type": "object",
            "properties": {
                "amount": { "type": "integer", "description": "Dollar amount (1-500)", "minimum": 1, "maximum": 500 },
                "moneyType": { "type": "string", "enum": ["cash", "bank"], "description": "Type of money" }
            },
            "required": ["amount", "moneyType"]
        }
        """)),

    ChatTool.CreateFunctionTool("take_money",
        "Charge the player money for a service, item, or debt. Use when selling something or collecting payment.",
        BinaryData.FromString("""
        {
            "type": "object",
            "properties": {
                "amount": { "type": "integer", "description": "Dollar amount (1-500)", "minimum": 1, "maximum": 500 },
                "moneyType": { "type": "string", "enum": ["cash", "bank"], "description": "Type of money" }
            },
            "required": ["amount", "moneyType"]
        }
        """)),
};

// ─── TTS ──────────────────────────────────────────────────────────────────────
async Task<string> GenerateTTSAsync(string agentName, string text)
{
    var audioDir = "audio";
    Directory.CreateDirectory(audioDir);

    // Clean up files older than 5 minutes
    foreach (var old in Directory.GetFiles(audioDir, "*.mp3"))
    {
        if (File.GetCreationTimeUtc(old) < DateTime.UtcNow.AddMinutes(-5))
            try { File.Delete(old); } catch { }
    }

    var filename = $"{agentName}_{DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()}.mp3";
    var path = Path.Combine(audioDir, filename);
    var audioClient = new AudioClient("tts-1", apiKey);
    var result = await audioClient.GenerateSpeechAsync(text, agentVoices[agentName]);
    await File.WriteAllBytesAsync(path, result.Value.ToArray());
    Console.WriteLine($"[TTS] {agentName}: {filename}");
    return filename;
}

// ─── Process tool calls from GPT response ────────────────────────────────────
List<Dictionary<string, object>> ProcessToolCalls(ChatCompletion completion)
{
    var actions = new List<Dictionary<string, object>>();
    foreach (var toolCall in completion.ToolCalls)
    {
        var args = JsonSerializer.Deserialize<Dictionary<string, JsonElement>>(toolCall.FunctionArguments.ToString())
            ?? new Dictionary<string, JsonElement>();

        var action = new Dictionary<string, object> { ["type"] = toolCall.FunctionName };
        foreach (var kvp in args)
        {
            action[kvp.Key] = kvp.Value.ValueKind switch
            {
                JsonValueKind.String => kvp.Value.GetString()!,
                JsonValueKind.Number => kvp.Value.GetInt32(),
                _ => kvp.Value.ToString()
            };
        }
        actions.Add(action);
    }
    return actions;
}

// ─── /talk ────────────────────────────────────────────────────────────────────
app.MapPost("/talk", async ([FromBody] TalkRequest request) =>
{
    if (!agents.ContainsKey(request.AgentName))
        return Results.BadRequest($"Unknown agent: {request.AgentName}");

    var playerId = request.PlayerId ?? "";
    var client = new ChatClient("gpt-4o-mini", apiKey);

    var systemPrompt = BuildSystemPrompt(
        request.AgentName, playerId, request.PlayerName,
        request.PlayerJob, request.PlayerJobLabel, request.PlayerGang,
        request.PlayerMoney?.Cash, request.PlayerMoney?.Bank
    );

    var messages = new List<ChatMessage> { new SystemChatMessage(systemPrompt) };
    foreach (var msg in GetMemory(request.AgentName, playerId).TakeLast(10))
        messages.Add(msg);
    messages.Add(new UserChatMessage(request.PlayerMessage));

    var options = new ChatCompletionOptions();
    foreach (var tool in gameTools)
        options.Tools.Add(tool);

    var response = await client.CompleteChatAsync(messages, options);
    var completion = response.Value;

    var actions = new List<Dictionary<string, object>>();
    string reply;

    // Handle tool calls — run them, feed results back, get final text
    if (completion.FinishReason == ChatFinishReason.ToolCalls)
    {
        actions = ProcessToolCalls(completion);

        // Add assistant message with tool calls
        messages.Add(new AssistantChatMessage(completion));

        // Add tool results (confirm each action)
        foreach (var toolCall in completion.ToolCalls)
        {
            messages.Add(new ToolChatMessage(toolCall.Id, $"Action '{toolCall.FunctionName}' will be executed."));
        }

        // Get the actual dialogue response
        var followUp = await client.CompleteChatAsync(messages, options);
        reply = followUp.Value.Content.Count > 0
            ? followUp.Value.Content[0].Text
            : "...";
    }
    else
    {
        reply = completion.Content.Count > 0
            ? completion.Content[0].Text
            : "...";
    }

    // Generate TTS audio
    var audioFile = "";
    try { audioFile = await GenerateTTSAsync(request.AgentName, reply); }
    catch (Exception ex) { Console.WriteLine($"[TTS] Error: {ex.Message}"); }

    // Fire-and-forget: classify tone → shift mood + player reputation
    _ = Task.Run(async () =>
    {
        try
        {
            var result = await new ChatClient("gpt-4o-mini", apiKey).CompleteChatAsync(new List<ChatMessage>
            {
                new SystemChatMessage("Classify the emotional tone of this player message with one word only: positive, negative, hostile, or neutral. No punctuation."),
                new UserChatMessage(request.PlayerMessage)
            });
            var tone = result.Value.Content[0].Text.Trim().ToLower();
            if (tone is "positive" or "negative" or "hostile" or "neutral")
            {
                ShiftMood(request.AgentName, tone);
                ApplyTimeOfDayMood(request.AgentName, request.GameHour);

                var repDelta = tone switch
                {
                    "positive" =>  1,
                    "negative" => -1,
                    "hostile"  => -3,
                    _          =>  0
                };
                if (repDelta != 0) ShiftReputation(request.AgentName, playerId, repDelta);
            }
        }
        catch (Exception ex) { Console.WriteLine($"[Mood/Rep] Tone error: {ex.Message}"); }
    });

    // Save to in-memory per-player history
    var mem = GetMemory(request.AgentName, playerId);
    mem.Add(new UserChatMessage(request.PlayerMessage));
    mem.Add(new AssistantChatMessage(reply));

    // Save to SQLite
    using (var conn = new SqliteConnection(connectionString))
    {
        conn.Open();
        var ts = DateTimeOffset.UtcNow.ToUnixTimeSeconds();

        using var insert = conn.CreateCommand();
        insert.CommandText = @"
            INSERT INTO memory (agent_name, player_id, role, content, timestamp)
            VALUES ($agent, $player, $role, $content, $ts)";
        insert.Parameters.AddWithValue("$agent", request.AgentName);
        insert.Parameters.AddWithValue("$player", playerId);
        insert.Parameters.AddWithValue("$ts",    ts);

        insert.Parameters.AddWithValue("$role",    "user");
        insert.Parameters.AddWithValue("$content", request.PlayerMessage);
        insert.ExecuteNonQuery();

        insert.Parameters["$role"].Value    = "assistant";
        insert.Parameters["$content"].Value = reply;
        insert.ExecuteNonQuery();

        using var trim = conn.CreateCommand();
        trim.CommandText = @"
            DELETE FROM memory
            WHERE agent_name = $agent AND player_id = $player
              AND id NOT IN (
                  SELECT id FROM memory
                  WHERE agent_name = $agent AND player_id = $player
                  ORDER BY id DESC LIMIT 50
              )";
        trim.Parameters.AddWithValue("$agent", request.AgentName);
        trim.Parameters.AddWithValue("$player", playerId);
        trim.ExecuteNonQuery();
    }

    LogEntry(new {
        timestamp = DateTime.UtcNow.ToString("o"),
        type      = "talk",
        agent     = request.AgentName,
        playerId,
        playerName = request.PlayerName,
        mood      = mood.GetOrAdd(request.AgentName, "neutral"),
        rep       = reputation.GetOrAdd(RepKey(request.AgentName, playerId), 0),
        input     = request.PlayerMessage,
        reply,
        actionCount = actions.Count
    });

    return Results.Ok(new { reply, audioFile, actions });
});

// ─── /react ───────────────────────────────────────────────────────────────────
var eventPrompts = new Dictionary<string, string>
{
    ["gunshot"]      = "You just heard a gunshot nearby. React in character with 1 short sentence.",
    ["explosion"]    = "There was a massive explosion nearby. React in character with 1 short sentence.",
    ["weapon_drawn"] = "A stranger just pulled out a weapon near you. React in character with 1 short sentence.",
    ["dead_ped"]     = "You just noticed a dead body nearby. React in character with 1 short sentence.",
};

var eventRepMap = new Dictionary<string, int>
{
    ["gunshot"]      = -3,
    ["explosion"]    = -5,
    ["weapon_drawn"] = -2,
    ["dead_ped"]     = -2,
};

app.MapPost("/react", async ([FromBody] ReactRequest request) =>
{
    if (!agents.ContainsKey(request.AgentName))
        return Results.BadRequest($"Unknown agent: {request.AgentName}");
    if (!eventPrompts.ContainsKey(request.EventType))
        return Results.BadRequest($"Unknown event: {request.EventType}");

    var client = new ChatClient("gpt-4o-mini", apiKey);

    var eventMoodMap = new Dictionary<string, string>
    {
        ["gunshot"]      = "scared",
        ["explosion"]    = "scared",
        ["weapon_drawn"] = "tense",
        ["dead_ped"]     = "tense",
    };
    if (eventMoodMap.TryGetValue(request.EventType, out var targetMood))
        ShiftMood(request.AgentName, request.EventType, targetMood);

    // Note: event reactions don't shift per-player reputation in multiplayer
    // (we don't know which player caused the event from the server event)

    var messages = new List<ChatMessage>
    {
        new SystemChatMessage(BuildSystemPrompt(request.AgentName)),
        new UserChatMessage(eventPrompts[request.EventType])
    };

    var response = await client.CompleteChatAsync(messages);
    var reply = response.Value.Content[0].Text;

    var audioFile = "";
    try { audioFile = await GenerateTTSAsync(request.AgentName, reply); }
    catch (Exception ex) { Console.WriteLine($"[TTS] Error: {ex.Message}"); }

    LogEntry(new {
        timestamp = DateTime.UtcNow.ToString("o"),
        type      = "react",
        agent     = request.AgentName,
        mood      = mood.GetOrAdd(request.AgentName, "neutral"),
        input     = request.EventType,
        reply
    });

    return Results.Ok(new { reply, audioFile });
});

// ─── /chat ────────────────────────────────────────────────────────────────────
app.MapPost("/chat", async ([FromBody] ChatRequest request) =>
{
    if (!agents.ContainsKey(request.InitiatorName))
        return Results.BadRequest($"Unknown initiator: {request.InitiatorName}");
    if (!agents.ContainsKey(request.ResponderName))
        return Results.BadRequest($"Unknown responder: {request.ResponderName}");

    var client = new ChatClient("gpt-4o-mini", apiKey);

    // Initiator speaks
    var initiatorMessages = new List<ChatMessage>
    {
        new SystemChatMessage(
            BuildSystemPrompt(request.InitiatorName) +
            $"\n\n[Instruction] You are speaking casually to {request.ResponderName}. " +
            "Say exactly one sentence — natural small talk, a complaint, or an observation. " +
            "No quotation marks. No greeting preamble. Just the line."
        ),
        new UserChatMessage($"Say something to {request.ResponderName}.")
    };
    var initiatorResponse = await client.CompleteChatAsync(initiatorMessages);
    var initiatorLine = initiatorResponse.Value.Content[0].Text.Trim();

    // Responder replies
    var responderMessages = new List<ChatMessage>
    {
        new SystemChatMessage(
            BuildSystemPrompt(request.ResponderName) +
            $"\n\n[Instruction] {request.InitiatorName} just said to you: \"{initiatorLine}\" " +
            "Reply with exactly one sentence, in character. No quotation marks. No preamble."
        ),
        new UserChatMessage($"Reply to {request.InitiatorName}.")
    };
    var responderResponse = await client.CompleteChatAsync(responderMessages);
    var responderLine = responderResponse.Value.Content[0].Text.Trim();

    // Generate TTS for both lines
    var initiatorAudio = "";
    var responderAudio = "";
    try { initiatorAudio = await GenerateTTSAsync(request.InitiatorName, initiatorLine); }
    catch (Exception ex) { Console.WriteLine($"[TTS] Initiator error: {ex.Message}"); }
    try { responderAudio = await GenerateTTSAsync(request.ResponderName, responderLine); }
    catch (Exception ex) { Console.WriteLine($"[TTS] Responder error: {ex.Message}"); }

    // Fire-and-forget: classify tone → shift agent-to-agent reputations
    _ = Task.Run(async () =>
    {
        try
        {
            var classifyResult = await new ChatClient("gpt-4o-mini", apiKey).CompleteChatAsync(new List<ChatMessage>
            {
                new SystemChatMessage(
                    $"Two people had a brief exchange. Classify the emotional tone of each toward the other. " +
                    $"Respond with exactly two comma-separated words (no spaces after comma), each being: positive, negative, hostile, or neutral. " +
                    $"First word = {request.InitiatorName}'s tone toward {request.ResponderName}. " +
                    $"Second word = {request.ResponderName}'s tone toward {request.InitiatorName}."
                ),
                new UserChatMessage(
                    $"{request.InitiatorName} said: \"{initiatorLine}\"\n{request.ResponderName} replied: \"{responderLine}\""
                )
            });

            var parts = classifyResult.Value.Content[0].Text.Trim().ToLower().Split(',');
            if (parts.Length == 2)
            {
                var toneMap = new Dictionary<string, int>
                {
                    ["positive"] =  1,
                    ["negative"] = -1,
                    ["hostile"]  = -2,
                    ["neutral"]  =  0
                };
                if (toneMap.TryGetValue(parts[0].Trim(), out var d1))
                    ShiftAgentReputation(request.InitiatorName, request.ResponderName, d1);
                if (toneMap.TryGetValue(parts[1].Trim(), out var d2))
                    ShiftAgentReputation(request.ResponderName, request.InitiatorName, d2);
            }
        }
        catch (Exception ex) { Console.WriteLine($"[A2ARep] Classify error: {ex.Message}"); }
    });

    LogEntry(new {
        timestamp     = DateTime.UtcNow.ToString("o"),
        type          = "a2a_chat",
        initiator     = request.InitiatorName,
        initiatorMood = mood.GetOrAdd(request.InitiatorName, "neutral"),
        responder     = request.ResponderName,
        responderMood = mood.GetOrAdd(request.ResponderName, "neutral"),
        initiatorLine,
        responderLine
    });

    Console.WriteLine($"[A2A] {request.InitiatorName}: {initiatorLine}");
    Console.WriteLine($"[A2A] {request.ResponderName}: {responderLine}");

    return Results.Ok(new { initiatorLine, responderLine, initiatorAudio, responderAudio });
});

// ─── /audio ───────────────────────────────────────────────────────────────────
app.MapGet("/audio/{filename}", (string filename) =>
{
    if (filename.Contains('/') || filename.Contains('\\') || filename.Contains(".."))
        return Results.BadRequest("Invalid filename");
    var path = Path.GetFullPath(Path.Combine("audio", filename));
    if (!File.Exists(path)) return Results.NotFound();
    return Results.File(path, "audio/mpeg");
});

app.MapGet("/health", () => "StabCity Bridge v2.0 (QBCore) is running!");

app.Run("http://localhost:5000");

// ─── Request records ──────────────────────────────────────────────────────────
public record PlayerMoney(int Cash = 0, int Bank = 0);

public record TalkRequest(
    string AgentName,
    string PlayerMessage,
    string? PlayerId = null,
    string? PlayerName = null,
    string? PlayerJob = null,
    string? PlayerJobLabel = null,
    string? PlayerJobGrade = null,
    string? PlayerGang = null,
    string? PlayerGangLabel = null,
    PlayerMoney? PlayerMoney = null,
    int GameHour = 0
);

public record ReactRequest(string AgentName, string EventType);
public record ChatRequest(string InitiatorName, string ResponderName);
