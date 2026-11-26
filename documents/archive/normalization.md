Our schema follows the standard normal forms to keep the database as free as possible of redundancy and update anomalies. Each table adheres to First Normal Form (1NF) because each column holds a single value. For example, a Reading stores one latitude, one pH, and one turbidity reading rather than cramming multiple sensor values into one field. We reached Second Normal Form (2NF) by making sure every non-key attribute depends on the "primary key", which matters most for our one composite-key table, "SampleDetection". Since its key is (sample\_id, polymer\_id), attributes like "particle\_count" and "absorbance" describe the combination of a specific sample and a specific polymer, not just one half of that pair. Finally, Third Normal Form (3NF) is what guided us to pull repeating, non-key-dependent facts into their own lookup tables. This meant that Drone, OperationalStatus, SamplingPoint, and PolymerType each exist so that descriptive details (a status's description, a sampling point's coordinates and runoff distance, a polymer's common sources) are stored once and referenced by ID everywhere else, instead of being copied onto every Run or Reading row where they could drift out of sync.



Beyond the textbook normal forms, a few structural choices show how the data is actually collected. Reading and WaterSample are split into separate tables linked 1:1 (via a UNIQUE foreign key) because a reading is captured instantly in the field while the physical sample may sit unanalyzed for days. Keeping them separate avoids a wide table full of NULL lab-result columns until analysis is done. SampleDetection exists as a junction table because the relationship between water samples and polymer types is many-to-many: one sample can contain several plastics, and the same polymer type shows up across many samples, so a bridging table with its own composite key was our way to model that relationship without duplicating data. Together, these decisions keep each fact recorded in one place, makes the database easier to query and rely on, and protect it from the insert/update/delete anomalies that unnormalized designs tend to have issues with.

## Does a single reading occur at multiple locations? ##



No. A reading happens at exactly one location. In the `Reading` table, `point\_id` is a single, `NOT NULL` foreign key to `SamplingPoint`, so every reading points to one and only one sampling point. The table rule `UNIQUE (run\_id, point\_id)` further guarantees that a given run records at most one reading per stop: a run cannot log the same point twice, and a reading cannot span two points.



The design deliberately stores location in two complementary places, which is the likely source of confusion:



\- `SamplingPoint` holds the "planned" stop — its label (e.g. NB-02), river

&#x20; mile, and the coordinates the drone is supposed to visit. These are fixed and reused across every run.

\- `Reading` holds the drone's "actual" GPS latitude/longitude at the moment of the reading, which may differ slightly from the planned point due to current or drift.



One reading, one location: identified both by the planned stop it belongs to and by the exact GPS coordinates where the drone actually took it.

