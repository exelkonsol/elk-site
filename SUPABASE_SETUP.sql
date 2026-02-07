-- ============================================
-- ELK VOTING SYSTEM - SUPABASE SETUP
-- Run this SQL in your Supabase SQL Editor
-- ============================================

-- 1. Create the votes table
CREATE TABLE IF NOT EXISTS elk_votes (
    id TEXT PRIMARY KEY DEFAULT 'current',
    isolation INTEGER DEFAULT 0,
    anchoring INTEGER DEFAULT 0,
    distraction INTEGER DEFAULT 0,
    sublimation INTEGER DEFAULT 0,
    cycle INTEGER DEFAULT 1,
    cycle_started_at TIMESTAMPTZ DEFAULT NOW(),
    cycle_ends_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '14 days'),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Insert the initial vote record
INSERT INTO elk_votes (id, isolation, anchoring, distraction, sublimation, cycle)
VALUES ('current', 0, 0, 0, 0, 1)
ON CONFLICT (id) DO NOTHING;

-- 3. Create the atomic increment function (prevents race conditions)
CREATE OR REPLACE FUNCTION increment_vote(mechanism_name TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSON;
BEGIN
    -- Validate mechanism name
    IF mechanism_name NOT IN ('isolation', 'anchoring', 'distraction', 'sublimation') THEN
        RAISE EXCEPTION 'Invalid mechanism: %', mechanism_name;
    END IF;

    -- Atomically increment the vote count
    EXECUTE format(
        'UPDATE elk_votes SET %I = %I + 1, updated_at = NOW() WHERE id = $1 RETURNING to_json(elk_votes.*)',
        mechanism_name, mechanism_name
    ) INTO result USING 'current';

    RETURN result;
END;
$$;

-- 4. Enable Row Level Security (RLS)
ALTER TABLE elk_votes ENABLE ROW LEVEL SECURITY;

-- 5. Create policies for public access
-- Allow anyone to read votes
CREATE POLICY "Allow public read access" ON elk_votes
    FOR SELECT USING (true);

-- Allow anyone to update votes (via RPC function)
CREATE POLICY "Allow public update access" ON elk_votes
    FOR UPDATE USING (true);

-- Allow insert for initial record creation
CREATE POLICY "Allow public insert access" ON elk_votes
    FOR INSERT WITH CHECK (true);

-- 6. Enable realtime for the table
ALTER PUBLICATION supabase_realtime ADD TABLE elk_votes;

-- ============================================
-- DONE! Now copy your Supabase URL and anon key
-- from Project Settings > API in your Supabase dashboard
-- ============================================
