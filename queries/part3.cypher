// ==========================================
// БАЗОВІ ЗАПИТИ
// ==========================================

// Запит 1. Знайти всі фільми жанру «Thriller» із середнім рейтингом вище 4.0
MATCH (m:Movie)-[:HAS_GENRE]->(g:Genre {name: 'Thriller'})
MATCH (u:User)-[r:RATED]->(m)
WITH m, avg(r.rating) AS avg_rate
WHERE avg_rate > 4.0
RETURN m.movieId AS movie_id, m.title AS title, round(avg_rate, 2) AS avg_rate
ORDER BY avg_rate DESC;

// Запит 2. Знайти користувачів, які поставили оцінку 5 більш ніж 50 фільмам
MATCH (u:User)-[r:RATED]->(m:Movie)
WHERE r.rating = 5.0
WITH u, count(r) AS five_star_cnt
WHERE five_star_cnt > 50
RETURN u.userId AS user_id, five_star_cnt
ORDER BY five_star_cnt DESC;

// ==========================================
// ЗАПИТИ СЕРЕДНЬОГО РІВНЯ
// ==========================================

// Запит 3. Знайти фільми, які обидва користувачі (userId=1 і userId=2) оцінили високо (рейтинг >= 4)
MATCH (u1:User {userId: 1})-[r1:RATED]->(m:Movie)<-[r2:RATED]-(u2:User {userId: 2})
WHERE r1.rating >= 4.0 AND r2.rating >= 4.0
RETURN m.movieId AS movie_id, m.title AS title, r1.rating AS u1_rating, r2.rating AS u2_rating;

// Запит 4. Знайти жанри, чиї фільми стабільно отримують високі оцінки (з порогом релевантності за кількістю)
MATCH (g:Genre)<-[:HAS_GENRE]-(m:Movie)<-[r:RATED]-(u:User)
WITH g, avg(r.rating) AS avg_rate, count(r) AS rate_cnt
WHERE rate_cnt >= 100
RETURN g.name AS genre, round(avg_rate, 2) AS avg_rate, rate_cnt
ORDER BY avg_rate DESC;

// ==========================================
// СКЛАДНІ ЗАПИТИ
// ==========================================

// Запит 5. Колаборативна фільтрація ("користувачі зі схожими смаками також дивилися")
MATCH (u:User {userId: 1})-[r1:RATED]->(m1:Movie)<-[r2:RATED]-(other:User)
WHERE r1.rating >= 4.0 AND r2.rating >= 4.0 AND u <> other
MATCH (other)-[r3:RATED]->(rec:Movie)
WHERE r3.rating >= 4.0 AND NOT (u)-[:RATED]->(rec)
WITH rec, count(DISTINCT other) AS score, avg(r3.rating) AS avg_rec_rate
RETURN rec.movieId AS movie_id, rec.title AS title, score, round(avg_rec_rate, 2) AS avg_rate
ORDER BY score DESC, avg_rate DESC
LIMIT 10;

// Запит 6. Найкоротший ланцюжок зв’язку між двома користувачами через спільні фільми
MATCH (u1:User {userId: 1}), (u2:User {userId: 2})
MATCH p = shortestPath((u1)-[:RATED*..10]-(u2))
RETURN p, length(p) AS path_len;