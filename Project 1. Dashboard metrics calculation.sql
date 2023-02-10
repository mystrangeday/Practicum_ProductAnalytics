-- 1. Рассчет DAU
SELECT log_date, COUNT(DISTINCT user_id) as dau, COUNT(*) AS events
FROM events_log
GROUP BY log_date
ORDER BY log_date;

-- 2. Расчет числа активных пользователей по источникам привлечения
SELECT utm_source, COUNT(DISTINCT user_id) AS users
FROM events_log
GROUP BY utm_source
ORDER BY users DESC

-- 3. Воронка просмотров (+рейтинг и комментарии)
WITH page_open AS
  (SELECT dt,
          log_date,
          user_id,
          app_id,
          utm_source,
          name
   FROM events_log
   WHERE name = 'pageOpen' ),
     search_type_table AS
  (SELECT dt,
          log_date,
          user_id,
          app_id,
          utm_source,
          name,
          object_details
   FROM events_log
   WHERE name IN ('searchDialog', 'tagClick') ),
     start_movie AS
  (SELECT dt,
          log_date,
          user_id,
          app_id,
          utm_source,
          object_id,
          object_details,
          name
   FROM events_log
   WHERE name = 'startMovie' ),
     end_movie AS
  (SELECT dt,
          log_date,
          user_id,
          app_id,
          utm_source,
          object_id,
          name
   FROM events_log
   WHERE name = 'endMovie' ),
     rating AS
  (SELECT dt,
          user_id,
          app_id,
          object_id
   FROM events_log
   WHERE name = 'rateMovie' ),
     comment AS
  (SELECT dt,
          user_id,
          app_id,
          object_id
   FROM events_log
   WHERE name = 'commentMovie' )
SELECT page_open.app_id AS app_id,
       page_open.utm_source AS utm_source,
       page_open.log_date AS log_date,
       COUNT(DISTINCT page_open.user_id) AS users_open_page,
       COUNT(DISTINCT search_type_table.user_id) AS users_search_type,
       COUNT(DISTINCT start_movie.user_id) AS users_start_movie,
       COUNT(DISTINCT end_movie.user_id) AS users_end_movie,
       COUNT(DISTINCT rating.user_id) AS users_rating,
       COUNT(DISTINCT comment.user_id) AS users_comment
FROM page_open
LEFT JOIN search_type_table ON page_open.user_id = search_type_table.user_id AND
                               page_open.log_date = search_type_table.log_date AND
                               page_open.app_id = search_type_table.app_id
LEFT JOIN start_movie ON start_movie.log_date = search_type_table.log_date AND
                         start_movie.user_id = search_type_table.user_id AND
                         start_movie.app_id = search_type_table.app_id AND
                         start_movie.object_details = search_type_table.object_details
LEFT JOIN end_movie ON start_movie.user_id = end_movie.user_id AND
                       start_movie.app_id = end_movie.app_id
LEFT JOIN rating ON end_movie.user_id = rating.user_id
LEFT JOIN comment ON rating.user_id = comment.user_id
WHERE (search_type_table.dt IS NULL
       OR page_open.dt <= search_type_table.dt
       AND (start_movie.dt IS NULL
            OR search_type_table.dt <= start_movie.dt
            AND (end_movie.dt IS NULL
                 OR start_movie.dt <= end_movie.dt)
            AND (rating.dt IS NULL
                 OR end_movie.dt <= rating.dt)))
GROUP BY page_open.log_date,
         page_open.app_id,
         page_open.utm_source
ORDER BY page_open.log_date


-- 4. Расчет средней оценки фильма и числа пользователей, которые его посмотрели
WITH top AS
  (SELECT object_id, COUNT(DISTINCT user_id) AS users
   FROM events_log
   WHERE name = 'startMovie'
   GROUP BY object_id),
     movie_rates AS
  (SELECT object_id, AVG(object_value::FLOAT) AS avg_rate
   FROM events_log
   WHERE name = 'rateMovie'
   GROUP BY object_id)
SELECT t.object_id,
       t.users,
       m.avg_rate
FROM top t
LEFT JOIN movie_rates m ON m.object_id = t.object_id
ORDER BY users DESC


-- 5. Воронка покупок
SELECT log_date,
       app_id,
       utm_source,
       name,
       object_id  AS offer_name,
       COUNT(DISTINCT user_id) AS all_users
FROM events_log
WHERE name IN ('offerShow','offerClicked','purchase') AND object_id ~ 'off'
GROUP BY log_date,
         app_id,
         utm_source,
         name,
         object_id
