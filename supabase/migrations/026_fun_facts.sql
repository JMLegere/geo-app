-- ══════════════════════════════════════════════════════════════════════════════
-- Migration 026: Fun Facts table + seed data
-- A self-growing pool of nature facts shown on the loading screen.
-- ══════════════════════════════════════════════════════════════════════════════

CREATE TABLE fun_facts (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  fact_text     TEXT NOT NULL CHECK (char_length(fact_text) BETWEEN 20 AND 300),
  category      TEXT NOT NULL CHECK (category IN (
    'species', 'conservation', 'natural_science', 'behavior', 'milestone'
  )),
  source        TEXT NOT NULL DEFAULT 'seed' CHECK (source IN ('seed', 'llm')),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_fun_facts_category ON fun_facts (category);

-- RLS: anyone can read, only service role can write
ALTER TABLE fun_facts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read fun facts"
  ON fun_facts FOR SELECT USING (true);

-- ── Seed data: 25 diverse facts across 5 categories ────────────────────────

INSERT INTO fun_facts (fact_text, category, source) VALUES

-- Species (5)
('The axolotl can regenerate its brain, heart, and limbs throughout its entire life — no scar tissue, just perfect regrowth.',
 'species', 'seed'),
('A pistol shrimp snaps its claw so fast it creates a cavitation bubble that briefly reaches 4,700°C — nearly as hot as the surface of the sun.',
 'species', 'seed'),
('The bar-tailed godwit flies 11,000 km from Alaska to New Zealand without stopping to eat, drink, or sleep — the longest non-stop flight of any bird.',
 'species', 'seed'),
('Tardigrades survive the vacuum of space, radiation 1,000× lethal to humans, and temperatures from −272°C to 150°C by entering a dehydrated state called a tun.',
 'species', 'seed'),
('The mimic octopus can impersonate at least 15 different species — including lionfish, flatfish, and sea snakes — by changing its shape, color, and behavior.',
 'species', 'seed'),

-- Conservation (5)
('Coral gardeners in Belize have regrown over 100,000 coral fragments on underwater nursery trees, restoring reefs that were 90% dead after bleaching events.',
 'conservation', 'seed'),
('Costa Rica reversed decades of deforestation and doubled its forest cover from 26% to 52% between 1983 and 2021 by paying landowners to protect trees.',
 'conservation', 'seed'),
('India created over 100 wildlife corridors connecting tiger reserves, allowing big cats to move between isolated populations and boosting genetic diversity.',
 'conservation', 'seed'),
('The Great Green Wall project aims to grow an 8,000 km belt of trees across the entire width of Africa to hold back the Sahara Desert.',
 'conservation', 'seed'),
('Gorongosa National Park in Mozambique went from near-zero large wildlife after civil war to thriving populations of elephants, lions, and wild dogs in just 15 years.',
 'conservation', 'seed'),

-- Natural Science (5)
('There is more water locked inside Earth''s mantle — in a mineral called ringwoodite — than in all the planet''s oceans combined.',
 'natural_science', 'seed'),
('A single teaspoon of healthy soil contains more microorganisms than there are people on Earth — roughly 6 to 10 billion bacteria alone.',
 'natural_science', 'seed'),
('The oldest known living organism is a seagrass meadow in the Mediterranean estimated to be between 80,000 and 200,000 years old.',
 'natural_science', 'seed'),
('Ocean currents move so slowly that water entering the deep Pacific today won''t return to the surface for about 1,000 years.',
 'natural_science', 'seed'),
('Lightning strikes create tubes of glass called fulgurites by fusing sand at 30,000°C — five times hotter than the surface of the sun.',
 'natural_science', 'seed'),

-- Behavior (5)
('Clark''s nutcrackers bury up to 98,000 pine seeds each autumn across thousands of locations and remember where most of them are months later.',
 'behavior', 'seed'),
('Cleaner wrasse fish pass the mirror self-recognition test — they try to remove marks placed on their bodies, a feat once thought exclusive to great apes.',
 'behavior', 'seed'),
('Army ants build living bridges and rafts from their own bodies, each ant locking its legs with its neighbors to create structures that span gaps and float on water.',
 'behavior', 'seed'),
('The bowerbird builds elaborate decorated stages from sticks, shells, and flowers — and uses forced perspective to make itself look larger to visiting females.',
 'behavior', 'seed'),
('Dolphins in Shark Bay, Australia, carry sea sponges on their noses to protect them while foraging on the seafloor — a tool-use behavior passed from mother to calf.',
 'behavior', 'seed'),

-- Milestones (5)
('The bald eagle was removed from the U.S. endangered species list in 2007 after its population recovered from 417 nesting pairs in 1963 to over 9,700.',
 'milestone', 'seed'),
('The Montreal Protocol, signed in 1987, has prevented over 2 million skin cancer cases per year and the ozone layer is on track to fully heal by 2066.',
 'milestone', 'seed'),
('Giant pandas were downlisted from Endangered to Vulnerable in 2016 after China''s bamboo corridor program increased the wild population by 17% in a decade.',
 'milestone', 'seed'),
('Gray wolves were reintroduced to Yellowstone in 1995, triggering a trophic cascade that changed river courses — elk moved, willows returned, and riverbanks stabilized.',
 'milestone', 'seed'),
('The global moratorium on commercial whaling in 1986 allowed humpback whale populations to rebound from 5,000 to over 80,000 individuals.',
 'milestone', 'seed');
