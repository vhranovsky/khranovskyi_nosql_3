// 1. Завантаження вузлів User
LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/vhranovsky/khranovskyi_nosql_3/main/import/users.csv' AS row
MERGE (u:User {userId: toInteger(row.userId)})
ON CREATE SET 
    u.gender = row.gender,
    u.age = toInteger(row.age),
    u.occupation = toInteger(row.occupation);

// 2. Завантаження вузлів Movie та їх Жанрів (Genre)
LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/vhranovsky/khranovskyi_nosql_3/main/import/movies.csv' AS row
MERGE (m:Movie {movieId: toInteger(row.movieId)})
ON CREATE SET m.title = row.title
WITH m, row
UNWIND split(row.genres, '|') AS genreName
MERGE (g:Genre {name: genreName})
MERGE (m)-[:HAS_GENRE]->(g);

// 3. Створення індексів (ОБОВ'ЯЗКОВО до завантаження ребер)
CREATE INDEX user_id_index IF NOT EXISTS FOR (u:User) ON (u.userId);
CREATE INDEX movie_id_index IF NOT EXISTS FOR (m:Movie) ON (m.movieId);
CREATE INDEX genre_name_index IF NOT EXISTS FOR (g:Genre) ON (g.name);

// 4. Завантаження ребер RATED (Батчінг через APOC)
CALL apoc.periodic.iterate(
    "LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/vhranovsky/khranovskyi_nosql_3/main/import/ratings.csv' AS row RETURN row LIMIT 200000",
    "
    MATCH (u:User {userId: toInteger(row.userId)})
    MATCH (m:Movie {movieId: toInteger(row.movieId)})
    MERGE (u)-[r:RATED]->(m)
    ON CREATE SET 
        r.rating = toFloat(row.rating),
        r.timestamp = toInteger(row.timestamp)
    ",
    {
        batchSize: 1000, 
        parallel: false, 
        iterateList: true, 
        retries: 3
    }
)