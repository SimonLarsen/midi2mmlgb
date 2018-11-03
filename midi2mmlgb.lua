local CHANNEL_NAMES = {"A","B","C","D"}
local NOTES = {"c", "c#", "d", "d#", "e", "f", "f#", "g", "g#", "a", "a#", "b"}
local TICKS_PER_FRAME = 20

local LENGTHS = {
    [192] = 1, [96] = 2, [64] = 3, [48] = 4, [32] = 6,
    [24] = 8, [16] = 12, [12] = 16, [8] = 24, [6] = 32
}

local function get_note(i)
    local note = i % 60 + 1
    local octave = math.floor((i - 12) / 12)
    return note, octave
end

local function get_length(ticks)
    if ticks % TICKS_PER_FRAME ~= 0 then
        error("Number of ticks not divisible with ticks per frame. Aborting.")
    end
    local length = LENGTHS[ticks / TICKS_PER_FRAME]
    if length == nil then
        length = "=" .. (ticks / TICKS_PER_FRAME)
    end
    return length
end

local function score2mmlgb(score, out)
    local channels = {
        {}, {}, {}, {}
    }

    for _, track in ipairs(score) do
        if type(track) == "table" then
            for _, e in ipairs(track) do
                if e[1] == "note" then
                    local note = {
                        type = "note",
                        start = e[2],
                        length = e[3],
                        note = e[5],
                        velocity = e[6]
                    }
                    table.insert(channels[e[4]+1], note)
                end
            end
        end
    end

    local max_channel_length = 0

    for ci, ch in ipairs(channels) do
        table.sort(ch, function(a, b) return a.start < b.start end)

        if #ch > 0 then
            local last = ch[#ch]
            max_channel_length = math.max(max_channel_length, last.start+last.length)
        end
    end

    for ci, ch in ipairs(channels) do
        local current_octave = nil
        out:write(CHANNEL_NAMES[ci], " ")
        time = 0
        for _, e in ipairs(ch) do
            if e.type == "note" then
                local note, octave = get_note(e.note)
                if octave ~= current_octave then
                    current_octave = octave
                    out:write("o", current_octave, " ")
                end

                if time < e.start then
                    out:write("r", get_length(e.start - time))
                end

                out:write(NOTES[note], get_length(e.length))

                time = e.start + e.length
            end
        end

        local rest = max_channel_length - time
        while rest > 0 do
            local ticks = math.min(rest, 192*TICKS_PER_FRAME)
            out:write("r", get_length(ticks))
            rest = rest - ticks
        end
        out:write("\n")
    end
end

local function main()
    local argparse = require("argparse")
    local MIDI = require("MIDI")

    local parser = argparse("midi2mml", "Convert MIDI files to MMLGB format.")
    parser:argument("input", "Input MIDI file.")
    parser:argument("output", "Output MML file.", "")
    local args = parser:parse()

    local f = assert(io.open(args.input, "r"))
    local data = f:read("*all")
    f:close()

    local score = MIDI.midi2score(data)

    local out = io.stdout
    if args.output ~= "" then
        out = assert(io.open(arg[2], "w"))
    end

    score2mmlgb(score, out)
    out:close()
end

main()
