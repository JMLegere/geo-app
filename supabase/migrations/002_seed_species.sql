-- Seed species table with 30 species (5 biomes × 6 each)
-- 3 rarity tiers per biome: 3 common, 2 uncommon, 1 rare

-- Forest (6 species)
INSERT INTO species (id, name, biome, rarity, description, season_availability) VALUES
('forest_001', 'Eastern Bluebird', 'forest', 'common', 'A bright blue songbird with a rusty breast', '{summer,winter}'),
('forest_002', 'White Oak', 'forest', 'common', 'A large deciduous tree with white-gray bark', '{summer,winter}'),
('forest_003', 'Red Fox', 'forest', 'common', 'A reddish canine predator with a bushy tail', '{summer,winter}'),
('forest_004', 'Scarlet Tanager', 'forest', 'uncommon', 'A bright red songbird with black wings', '{summer}'),
('forest_005', 'Black Birch', 'forest', 'uncommon', 'A hardwood tree with dark bark and aromatic twigs', '{summer,winter}'),
('forest_006', 'Pileated Woodpecker', 'forest', 'rare', 'A large black woodpecker with a red crest', '{summer,winter}');

-- Grassland (6 species)
INSERT INTO species (id, name, biome, rarity, description, season_availability) VALUES
('grassland_001', 'Eastern Meadowlark', 'grassland', 'common', 'A yellow songbird with a black breast patch', '{summer}'),
('grassland_002', 'Big Bluestem', 'grassland', 'common', 'A tall prairie grass with three-pronged seed heads', '{summer,winter}'),
('grassland_003', 'Coyote', 'grassland', 'common', 'A wild canine predator of open grasslands', '{summer,winter}'),
('grassland_004', 'Prairie Blazing Star', 'grassland', 'uncommon', 'A purple wildflower that blooms in late summer', '{summer}'),
('grassland_005', 'Black-footed Ferret', 'grassland', 'uncommon', 'A rare mustelid predator of prairie dog colonies', '{summer,winter}'),
('grassland_006', 'Greater Prairie-Chicken', 'grassland', 'rare', 'A large grouse with elaborate courtship displays', '{summer,winter}');

-- Wetland (6 species)
INSERT INTO species (id, name, biome, rarity, description, season_availability) VALUES
('wetland_001', 'Great Blue Heron', 'wetland', 'common', 'A large wading bird with blue-gray plumage', '{summer,winter}'),
('wetland_002', 'Cattail', 'wetland', 'common', 'A tall marsh plant with brown seed spikes', '{summer,winter}'),
('wetland_003', 'Muskrat', 'wetland', 'common', 'A semi-aquatic rodent that builds lodges', '{summer,winter}'),
('wetland_004', 'American Bittern', 'wetland', 'uncommon', 'A cryptic wading bird with booming calls', '{summer}'),
('wetland_005', 'Sphagnum Moss', 'wetland', 'uncommon', 'A peat-forming moss found in bogs', '{summer,winter}'),
('wetland_006', 'Wood Stork', 'wetland', 'rare', 'A large white wading bird with a dark head', '{summer}');

-- Urban (6 species)
INSERT INTO species (id, name, biome, rarity, description, season_availability) VALUES
('urban_001', 'Pigeon', 'urban', 'common', 'A gray and white bird common in cities', '{summer,winter}'),
('urban_002', 'Ragweed', 'urban', 'common', 'A common weed that causes allergies', '{summer,winter}'),
('urban_003', 'Squirrel', 'urban', 'common', 'A bushy-tailed rodent found in parks and yards', '{summer,winter}'),
('urban_004', 'Peregrine Falcon', 'urban', 'uncommon', 'A swift raptor that hunts pigeons in cities', '{summer,winter}'),
('urban_005', 'Window Box Herb', 'urban', 'uncommon', 'Cultivated herbs grown in urban gardens', '{summer}'),
('urban_006', 'Ocelot', 'urban', 'rare', 'A small spotted wild cat (rare in urban areas)', '{summer,winter}');

-- Coastal (6 species)
INSERT INTO species (id, name, biome, rarity, description, season_availability) VALUES
('coastal_001', 'Seagull', 'coastal', 'common', 'A white and gray gull common on beaches', '{summer,winter}'),
('coastal_002', 'Beach Grass', 'coastal', 'common', 'A hardy grass that stabilizes sand dunes', '{summer,winter}'),
('coastal_003', 'Crab', 'coastal', 'common', 'A crustacean found in tide pools and sandy shores', '{summer,winter}'),
('coastal_004', 'Roseate Tern', 'coastal', 'uncommon', 'A delicate white seabird with a pink breast', '{summer}'),
('coastal_005', 'Sea Lettuce', 'coastal', 'uncommon', 'A green edible seaweed found in shallow waters', '{summer,winter}'),
('coastal_006', 'Horseshoe Crab', 'coastal', 'rare', 'An ancient arthropod with blue blood', '{summer,winter}');
