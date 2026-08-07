
// 1. Пошук топ-20 супервузлів у всій базі даних за загальним ступенем(cnt)
MATCH (n)
WITH n, COUNT { (n)--() } AS cnt
WHERE cnt > 1000
RETURN labels(n) AS labels, 
       coalesce(n.title, toString(n.userId), n.name) AS node_id, 
       cnt
ORDER BY cnt DESC
LIMIT 20;

// 2. Пошук категоріальних супервузлів (Вузли Genre)
MATCH (g:Genre)<-[r:HAS_GENRE]-(m:Movie)
WITH g, count(r) AS cnt
RETURN g.name AS genre, cnt
ORDER BY cnt DESC;

// 3. Пошук супервузлів серед фільмів(Movies з найбільшою кількістю оцінок)
MATCH (m:Movie)<-[r:RATED]-(:User)
WITH m, count(r) AS cnt
WHERE cnt > 1000
RETURN m.movieId AS movie_id, m.title AS title, cnt
ORDER BY cnt DESC
LIMIT 10;

// 4. Пошук супервузлів серед користувачів(Hyperactive Users)
MATCH (u:User)-[r:RATED]->(:Movie)
WITH u, count(r) AS cnt
WHERE cnt > 1000
RETURN u.userId AS user_id, cnt
ORDER BY cnt DESC
LIMIT 10;