/// Test fixture JSON string for 50 species records covering all 7 habitats,
/// all 6 continents, all 6 IUCN statuses, and multiple taxonomic classes.
///
/// Used in species-related tests instead of loading the full 33k dataset.
const String kSpeciesFixtureJson = r'''
[
  {
    "commonName": "Red Fox",
    "scientificName": "Vulpes vulpes",
    "taxonomicClass": "Mammalia",
    "continents": ["Europe", "Asia", "North America"],
    "habitats": ["Forest", "Plains"],
    "iucnStatus": "Least Concern"
  },
  {
    "commonName": "European Badger",
    "scientificName": "Meles meles",
    "taxonomicClass": "Mammalia",
    "continents": ["Europe", "Asia"],
    "habitats": ["Forest"],
    "iucnStatus": "Least Concern"
  },
  {
    "commonName": "Amur Leopard",
    "scientificName": "Panthera pardus orientalis",
    "taxonomicClass": "Mammalia",
    "continents": ["Asia"],
    "habitats": ["Forest"],
    "iucnStatus": "Critically Endangered"
  },
  {
    "commonName": "Siberian Tiger",
    "scientificName": "Panthera tigris altaica",
    "taxonomicClass": "Mammalia",
    "continents": ["Asia"],
    "habitats": ["Forest"],
    "iucnStatus": "Endangered"
  },
  {
    "commonName": "Eurasian Lynx",
    "scientificName": "Lynx lynx",
    "taxonomicClass": "Mammalia",
    "continents": ["Europe", "Asia"],
    "habitats": ["Forest", "Mountain"],
    "iucnStatus": "Least Concern"
  },
  {
    "commonName": "Snow Leopard",
    "scientificName": "Panthera uncia",
    "taxonomicClass": "Mammalia",
    "continents": ["Asia"],
    "habitats": ["Mountain"],
    "iucnStatus": "Vulnerable"
  },
  {
    "commonName": "Marco Polo Sheep",
    "scientificName": "Ovis ammon polii",
    "taxonomicClass": "Mammalia",
    "continents": ["Asia"],
    "habitats": ["Mountain"],
    "iucnStatus": "Near Threatened"
  },
  {
    "commonName": "Alpine Ibex",
    "scientificName": "Capra ibex",
    "taxonomicClass": "Mammalia",
    "continents": ["Europe"],
    "habitats": ["Mountain"],
    "iucnStatus": "Least Concern"
  },
  {
    "commonName": "Saharan Cheetah",
    "scientificName": "Acinonyx jubatus hecki",
    "taxonomicClass": "Mammalia",
    "continents": ["Africa"],
    "habitats": ["Desert"],
    "iucnStatus": "Critically Endangered"
  },
  {
    "commonName": "Dromedary",
    "scientificName": "Camelus dromedarius",
    "taxonomicClass": "Mammalia",
    "continents": ["Africa", "Asia"],
    "habitats": ["Desert"],
    "iucnStatus": "Least Concern"
  },
  {
    "commonName": "Fennec Fox",
    "scientificName": "Vulpes zerda",
    "taxonomicClass": "Mammalia",
    "continents": ["Africa"],
    "habitats": ["Desert"],
    "iucnStatus": "Least Concern"
  },
  {
    "commonName": "Nile Crocodile",
    "scientificName": "Crocodylus niloticus",
    "taxonomicClass": "Reptilia",
    "continents": ["Africa"],
    "habitats": ["Freshwater", "Swamp"],
    "iucnStatus": "Least Concern"
  },
  {
    "commonName": "Hippo",
    "scientificName": "Hippopotamus amphibius",
    "taxonomicClass": "Mammalia",
    "continents": ["Africa"],
    "habitats": ["Freshwater", "Swamp"],
    "iucnStatus": "Vulnerable"
  },
  {
    "commonName": "Giant Otter",
    "scientificName": "Pteronura brasiliensis",
    "taxonomicClass": "Mammalia",
    "continents": ["South America"],
    "habitats": ["Freshwater"],
    "iucnStatus": "Endangered"
  },
  {
    "commonName": "Arapaima",
    "scientificName": "Arapaima gigas",
    "taxonomicClass": "Actinopterygii",
    "continents": ["South America"],
    "habitats": ["Freshwater"],
    "iucnStatus": "Least Concern"
  },
  {
    "commonName": "Pink River Dolphin",
    "scientificName": "Inia geoffrensis",
    "taxonomicClass": "Mammalia",
    "continents": ["South America"],
    "habitats": ["Freshwater"],
    "iucnStatus": "Endangered"
  },
  {
    "commonName": "Manatee",
    "scientificName": "Trichechus manatus",
    "taxonomicClass": "Mammalia",
    "continents": ["North America", "South America"],
    "habitats": ["Saltwater", "Freshwater"],
    "iucnStatus": "Vulnerable"
  },
  {
    "commonName": "Great White Shark",
    "scientificName": "Carcharodon carcharias",
    "taxonomicClass": "Chondrichthyes",
    "continents": ["Oceania", "Africa", "North America"],
    "habitats": ["Saltwater"],
    "iucnStatus": "Vulnerable"
  },
  {
    "commonName": "Blue Whale",
    "scientificName": "Balaenoptera musculus",
    "taxonomicClass": "Mammalia",
    "continents": ["Oceania", "North America", "South America"],
    "habitats": ["Saltwater"],
    "iucnStatus": "Endangered"
  },
  {
    "commonName": "Hawksbill Sea Turtle",
    "scientificName": "Eretmochelys imbricata",
    "taxonomicClass": "Reptilia",
    "continents": ["Oceania", "Africa", "Asia"],
    "habitats": ["Saltwater"],
    "iucnStatus": "Critically Endangered"
  },
  {
    "commonName": "Vaquita",
    "scientificName": "Phocoena sinus",
    "taxonomicClass": "Mammalia",
    "continents": ["North America"],
    "habitats": ["Saltwater"],
    "iucnStatus": "Critically Endangered"
  },
  {
    "commonName": "Jaguar",
    "scientificName": "Panthera onca",
    "taxonomicClass": "Mammalia",
    "continents": ["South America", "North America"],
    "habitats": ["Forest", "Swamp"],
    "iucnStatus": "Near Threatened"
  },
  {
    "commonName": "Capybara",
    "scientificName": "Hydrochoerus hydrochaeris",
    "taxonomicClass": "Mammalia",
    "continents": ["South America"],
    "habitats": ["Swamp", "Freshwater"],
    "iucnStatus": "Least Concern"
  },
  {
    "commonName": "Green Anaconda",
    "scientificName": "Eunectes murinus",
    "taxonomicClass": "Reptilia",
    "continents": ["South America"],
    "habitats": ["Swamp", "Freshwater"],
    "iucnStatus": "Least Concern"
  },
  {
    "commonName": "American Alligator",
    "scientificName": "Alligator mississippiensis",
    "taxonomicClass": "Reptilia",
    "continents": ["North America"],
    "habitats": ["Swamp", "Freshwater"],
    "iucnStatus": "Least Concern"
  },
  {
    "commonName": "Whooping Crane",
    "scientificName": "Grus americana",
    "taxonomicClass": "Aves",
    "continents": ["North America"],
    "habitats": ["Swamp", "Plains"],
    "iucnStatus": "Endangered"
  },
  {
    "commonName": "Bison",
    "scientificName": "Bison bison",
    "taxonomicClass": "Mammalia",
    "continents": ["North America"],
    "habitats": ["Plains"],
    "iucnStatus": "Near Threatened"
  },
  {
    "commonName": "Pronghorn",
    "scientificName": "Antilocapra americana",
    "taxonomicClass": "Mammalia",
    "continents": ["North America"],
    "habitats": ["Plains"],
    "iucnStatus": "Least Concern"
  },
  {
    "commonName": "African Elephant",
    "scientificName": "Loxodonta africana",
    "taxonomicClass": "Mammalia",
    "continents": ["Africa"],
    "habitats": ["Plains", "Forest"],
    "iucnStatus": "Vulnerable"
  },
  {
    "commonName": "Black Rhinoceros",
    "scientificName": "Diceros bicornis",
    "taxonomicClass": "Mammalia",
    "continents": ["Africa"],
    "habitats": ["Plains"],
    "iucnStatus": "Critically Endangered"
  },
  {
    "commonName": "Lion",
    "scientificName": "Panthera leo",
    "taxonomicClass": "Mammalia",
    "continents": ["Africa", "Asia"],
    "habitats": ["Plains"],
    "iucnStatus": "Vulnerable"
  },
  {
    "commonName": "Cheetah",
    "scientificName": "Acinonyx jubatus",
    "taxonomicClass": "Mammalia",
    "continents": ["Africa"],
    "habitats": ["Plains"],
    "iucnStatus": "Vulnerable"
  },
  {
    "commonName": "Kakapo",
    "scientificName": "Strigops habroptilus",
    "taxonomicClass": "Aves",
    "continents": ["Oceania"],
    "habitats": ["Forest"],
    "iucnStatus": "Critically Endangered"
  },
  {
    "commonName": "Tasmanian Devil",
    "scientificName": "Sarcophilus harrisii",
    "taxonomicClass": "Mammalia",
    "continents": ["Oceania"],
    "habitats": ["Forest", "Plains"],
    "iucnStatus": "Endangered"
  },
  {
    "commonName": "Platypus",
    "scientificName": "Ornithorhynchus anatinus",
    "taxonomicClass": "Mammalia",
    "continents": ["Oceania"],
    "habitats": ["Freshwater"],
    "iucnStatus": "Near Threatened"
  },
  {
    "commonName": "Wombat",
    "scientificName": "Vombatus ursinus",
    "taxonomicClass": "Mammalia",
    "continents": ["Oceania"],
    "habitats": ["Plains", "Forest"],
    "iucnStatus": "Least Concern"
  },
  {
    "commonName": "Komodo Dragon",
    "scientificName": "Varanus komodoensis",
    "taxonomicClass": "Reptilia",
    "continents": ["Asia"],
    "habitats": ["Desert", "Forest"],
    "iucnStatus": "Endangered"
  },
  {
    "commonName": "Indian Rhino",
    "scientificName": "Rhinoceros unicornis",
    "taxonomicClass": "Mammalia",
    "continents": ["Asia"],
    "habitats": ["Plains", "Swamp"],
    "iucnStatus": "Vulnerable"
  },
  {
    "commonName": "Orangutan",
    "scientificName": "Pongo pygmaeus",
    "taxonomicClass": "Mammalia",
    "continents": ["Asia"],
    "habitats": ["Forest"],
    "iucnStatus": "Critically Endangered"
  },
  {
    "commonName": "Giant Panda",
    "scientificName": "Ailuropoda melanoleuca",
    "taxonomicClass": "Mammalia",
    "continents": ["Asia"],
    "habitats": ["Forest", "Mountain"],
    "iucnStatus": "Vulnerable"
  },
  {
    "commonName": "Yangtze Finless Porpoise",
    "scientificName": "Neophocaena asiaeorientalis",
    "taxonomicClass": "Mammalia",
    "continents": ["Asia"],
    "habitats": ["Freshwater"],
    "iucnStatus": "Critically Endangered"
  },
  {
    "commonName": "Iberian Lynx",
    "scientificName": "Lynx pardinus",
    "taxonomicClass": "Mammalia",
    "continents": ["Europe"],
    "habitats": ["Forest", "Plains"],
    "iucnStatus": "Endangered"
  },
  {
    "commonName": "European Bison",
    "scientificName": "Bison bonasus",
    "taxonomicClass": "Mammalia",
    "continents": ["Europe"],
    "habitats": ["Forest", "Plains"],
    "iucnStatus": "Near Threatened"
  },
  {
    "commonName": "Mediterranean Monk Seal",
    "scientificName": "Monachus monachus",
    "taxonomicClass": "Mammalia",
    "continents": ["Europe", "Africa"],
    "habitats": ["Saltwater"],
    "iucnStatus": "Endangered"
  },
  {
    "commonName": "Balearic Shearwater",
    "scientificName": "Puffinus mauretanicus",
    "taxonomicClass": "Aves",
    "continents": ["Europe"],
    "habitats": ["Saltwater"],
    "iucnStatus": "Critically Endangered"
  },
  {
    "commonName": "Saiga Antelope",
    "scientificName": "Saiga tatarica",
    "taxonomicClass": "Mammalia",
    "continents": ["Europe", "Asia"],
    "habitats": ["Plains", "Desert"],
    "iucnStatus": "Critically Endangered"
  },
  {
    "commonName": "Polar Bear",
    "scientificName": "Ursus maritimus",
    "taxonomicClass": "Mammalia",
    "continents": ["North America", "Europe", "Asia"],
    "habitats": ["Mountain", "Saltwater"],
    "iucnStatus": "Vulnerable"
  },
  {
    "commonName": "Grizzly Bear",
    "scientificName": "Ursus arctos horribilis",
    "taxonomicClass": "Mammalia",
    "continents": ["North America"],
    "habitats": ["Forest", "Mountain"],
    "iucnStatus": "Least Concern"
  },
  {
    "commonName": "Gray Wolf",
    "scientificName": "Canis lupus",
    "taxonomicClass": "Mammalia",
    "continents": ["North America", "Europe", "Asia"],
    "habitats": ["Forest", "Plains"],
    "iucnStatus": "Least Concern"
  },
  {
    "commonName": "Passenger Pigeon",
    "scientificName": "Ectopistes migratorius",
    "taxonomicClass": "Aves",
    "continents": ["North America"],
    "habitats": ["Forest"],
    "iucnStatus": "Extinct"
  }
]
''';
