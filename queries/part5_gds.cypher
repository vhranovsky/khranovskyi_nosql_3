// =====================================================================
// ЧАСТИНА 5.1: Алгоритм PageRank на графі взємопов'язаних фільмів
// =====================================================================

// Крок 1: Матеріалізація ребер CO_RATED між фільмами
MATCH (m1:Movie)<-[r1:RATED]-(u:User)-[r2:RATED]->(m2:Movie)
WHERE r1.rating >= 4 AND r2.rating >= 4 AND m1.movieId < m2.movieId
WITH m1, m2, count(u) AS weight
WHERE COUNT { (m1)<-[:RATED]-() } > 20
  AND COUNT { (m2)<-[:RATED]-() } > 20
WITH m1, m2, weight
ORDER BY weight DESC
LIMIT 2500
MERGE (m1)-[co:CO_RATED]-(m2)
SET co.weight = toFloat(weight);

// Крок 2: Створення проєкції графа в оперативній пам'яті GDS
CALL gds.graph.project(
  'movie_g',
  'Movie',
  { CO_RATED: { orientation: 'UNDIRECTED', properties: 'weight' } }
)
YIELD graphName, nodeCount, relationshipCount;

// Крок 3: Запуск алгоритму PageRank (Stream mode з урахуванням вагових коефіцієнтів)
CALL gds.pageRank.stream('movie_g', {
  maxIterations: 20,
  dampingFactor: 0.85,
  relationshipWeightProperty: 'weight'
})
YIELD nodeId, score
RETURN gds.util.asNode(nodeId).movieId AS movie_id,
       gds.util.asNode(nodeId).title AS title,
       round(score, 4) AS p_rank_score
ORDER BY p_rank_score DESC
LIMIT 10;

// Крок 4: Очищення - видалення проєкції з пам'яті та матеріалізованих ребер
CALL gds.graph.drop('movie_g') YIELD graphName;
MATCH ()-[co:CO_RATED]-() DELETE co;

// =====================================================================
// ЧАСТИНА 5.2: Алгоритм Louvain (Виявлення спільнот)
// =====================================================================

// Крок 1: Матеріалізація ребер SIMILAR (Оптимізовано під ліміти)
MATCH (u1:User)-[r1:RATED]->(m:Movie)<-[r2:RATED]-(u2:User)
WHERE r1.rating >= 4 AND r2.rating >= 4 AND u1.userId < u2.userId
WITH u1, u2, count(m) AS weight
ORDER BY weight DESC
LIMIT 2500 // Жорсткий ліміт для економії місця в Aura Free
MERGE (u1)-[sim:SIMILAR]-(u2)
SET sim.weight = toFloat(weight);

// Крок 2: Створення проєкції
CALL gds.graph.project(
  'userSimilarity',
  'User',
  { SIMILAR: { orientation: 'UNDIRECTED', properties: 'weight' } }
)
YIELD graphName, nodeCount, relationshipCount;

// Крок 3: Запуск Louvain у режимі WRITE (Записуємо ID кластера у вузли User)
CALL gds.louvain.write('userSimilarity', {
  relationshipWeightProperty: 'weight',
  writeProperty: 'communityId'
})
YIELD communityCount, modularities;

// Крок 4.1: Виведення 10 найбільших кластерів
MATCH (u:User)
WHERE u.communityId IS NOT NULL
WITH u.communityId AS community, count(u) AS cluster_size
ORDER BY cluster_size DESC
LIMIT 10
RETURN community, cluster_size;

// Крок 4.2: Аналіз смаків - Топ-3 жанри для кожного з 10 найбільших кластерів
MATCH (u:User)
WHERE u.communityId IS NOT NULL
WITH u.communityId AS community, count(u) AS cluster_size
ORDER BY cluster_size DESC
LIMIT 10
MATCH (u:User {communityId: community})-[r:RATED]->(m:Movie)-[:HAS_GENRE]->(g:Genre)
WHERE r.rating >= 4.0
WITH community, cluster_size, g.name AS genre, count(r) AS genre_count
ORDER BY community, genre_count DESC
WITH community, cluster_size, collect(genre)[0..3] AS top_genres
RETURN community, cluster_size, top_genres
ORDER BY cluster_size DESC;

// Крок 5: Очищення (Видаляємо проєкцію, ребра та зчищаємо властивість communityId)
CALL gds.graph.drop('userSimilarity') YIELD graphName;
MATCH ()-[sim:SIMILAR]-() DELETE sim;
MATCH (u:User) WHERE u.communityId IS NOT NULL REMOVE u.communityId;

// =====================================================================
// ЧАСТИНА 5.3: Алгоритм Дейкстри (Пошук найкоротшого шляху)
// =====================================================================

// Крок 1: Матеріалізація ребер SIMILAR між користувачами
MATCH (u1:User)-[r1:RATED]->(m:Movie)<-[r2:RATED]-(u2:User)
WHERE r1.rating >= 4 AND r2.rating >= 4 AND u1.userId < u2.userId
WITH u1, u2, count(m) AS weight
ORDER BY weight DESC
LIMIT 2500 // Ліміт для збереження стабільності баз даних у хмарі
MERGE (u1)-[sim:SIMILAR]-(u2)
SET sim.weight = toFloat(weight);

// Крок 2: Створення проєкції в пам'яті GDS
CALL gds.graph.project(
  'movie_g',
  'User',
  { SIMILAR: { orientation: 'UNDIRECTED', properties: 'weight' } }
)
YIELD graphName, nodeCount, relationshipCount;

// Крок 3: Запуск алгоритму Дейкстри для конкретної пари користувачів
MATCH (source:User {userId: 1}), (target:User {userId: 10})
CALL gds.shortestPath.dijkstra.stream('movie_g', {
    sourceNode: source,
    targetNode: target,
    relationshipWeightProperty: 'weight'
})
YIELD index, sourceNode, targetNode, totalCost, nodeIds, costs
RETURN
    gds.util.asNode(sourceNode).userId AS source_uid,
    gds.util.asNode(targetNode).userId AS target_uid,
    totalCost,
    [nodeId IN nodeIds | gds.util.asNode(nodeId).userId] AS path_uids,
    size(nodeIds) - 1 AS pathLength;

// Крок 4: Очищення — видалення проєкції та матеріалізованих ребер
CALL gds.graph.drop('movie_g') YIELD graphName;
MATCH ()-[sim:SIMILAR]-() DELETE sim;