/* Ad-hoc requests */ 

/* Business Request 1 : total_trips, avg fare per km, avg fare per trip, and the % contribution of each city's trips to overall trips */
SELECT
c.city_name, 
count(trip_id) as total_trips, 
round(sum(fare_amount)/sum(distance_travelled_km), 3) as avg_fare_per_km,
round(avg(fare_amount),2) as avg_fare_per_trip, 
round(100 * count(trip_id)/ (select count(trip_id) from fact_trips) , 2) as 'contribution %'
FROM dim_city c join fact_trips t on c.city_id = t.city_id
group by 1 ;


/* Business Request 2 :  Generate a report that evaluates the target performance for trips at the monthly and city level.
 For each city and month compare the actual total trips with the target trips and categorise the performance as follows:
if actual trips > target trips, mark it as " Above Target " else, "Below Target" */

with trip_cte as (
SELECT c.city_name, monthname(tr.date) as `month`, tr.city_id, count(tr.trip_id) as actual_trip
FROM  dim_city c inner join fact_trips tr ON c.city_id = tr.city_id
group by c.city_name, tr.city_id, monthname(tr.date)
)
SELECT tc.city_name, monthname(tar.`month`) as `Month`, tc.actual_trip, tar.total_target_trips,
ROUND(100 * (tc.actual_trip - tar.total_target_trips )/tar.total_target_trips, 2) as 'Difference %',
CASE 
	WHEN tc.actual_trip > tar.total_target_trips THEN "Above Target"
    ELSE "Below Target" END AS "Performance"
FROM 
trip_cte tc INNER JOIN monthly_target_trips tar 
ON tc.city_id = tar.city_id AND tc.`month` = monthname(tar.month) 
order by tc.city_name;



/* BUSINESS REQUEST 3 : City-level repeat passanger trip frequency report */
with cte1 as (
SELECT city_id, trip_count, sum(repeat_passenger_count) as total_rp
from dim_repeat_trip_distribution group by 1,2
),
cte2 as (
select city_id, trip_count, total_rp, sum(city_id) over (partition by city_id) as city_total_rp,
concat(round(100 * total_rp/sum(total_rp) over (partition by city_id),2),'%') as contribution_pct
from cte1 group by city_id, trip_count
)
SELECT 
dc.city_name, 
sum(CASE WHEN trip_count = '2-trips' then contribution_pct else 0 end) as '2-trips',
sum(CASE WHEN trip_count = '3-trips' then contribution_pct else 0 end) as '3-trips',
sum(CASE WHEN trip_count = '4-trips' then contribution_pct else 0 end) as '4-trips',
sum(CASE WHEN trip_count = '5-trips' then contribution_pct else 0 end) as '5-trips',
sum(CASE WHEN trip_count = '6-trips' then contribution_pct else 0 end) as '6-trips',
sum(CASE WHEN trip_count = '7-trips' then contribution_pct else 0 end) as '7-trips',
sum(CASE WHEN trip_count = '8-trips' then contribution_pct else 0 end) as '8-trips',
sum(CASE WHEN trip_count = '9-trips' then contribution_pct else 0 end) as '9-trips',
sum(CASE WHEN trip_count = '10-trips' then contribution_pct else 0 end) as '10-trips'
FROM cte2 join dim_city dc on cte2.city_id = dc.city_id
group by dc.city_name ;
 
 
/* Business Request 4: Highest and Lowest new passengers */ 
WITH CTE AS (
(SELECT 
c.city_name, COUNT(passenger_type) as total_new_passangers FROM dim_city c join fact_trips t on c.city_id = t.city_id
WHERE passenger_type = "new" GROUP BY 1 ORDER BY total_new_passangers desc  )
UNION
(SELECT c.city_name, COUNT(passenger_type) as total_new_passangers FROM dim_city c join fact_trips t on c.city_id = t.city_id
WHERE passenger_type = "new" GROUP BY 1 ORDER BY total_new_passangers ASC ) 
),
cte2 as (
SELECT *, RANK() over ( order by total_new_passangers desc) as drnk,
CASE WHEN RANK() over ( order by total_new_passangers desc) = 1 then "Top 3"
	 WHEN RANK() over ( order by total_new_passangers desc) = 2 then "Top 3"
     WHEN RANK() over ( order by total_new_passangers desc) = 3 then "Top 3"
     WHEN RANK() over ( order by total_new_passangers desc) = 8 then "Bottom 3"
     WHEN RANK() over ( order by total_new_passangers desc) = 9 then "Bottom 3"
     WHEN RANK() over ( order by total_new_passangers desc) = 10 then "Bottom 3" 
END AS "City category"
FROM CTE 
)
select city_name, total_new_passangers, `City category` from cte2 
where drnk = 1 or drnk = 2 or drnk = 3 or drnk = 8 or drnk = 9 or drnk = 10;
 
 
 /* Ad-hoc 5 :  Generate a report that identifies the month with highest revenue for each city. 
 For each city, display the month_name, the revenue amount for that month, and the percentage contribution of that
 month's revenue to the city's total revenue. */
WITH CTE AS(
SELECT city_id, 
MONTHNAME(date) AS month, SUM(fare_amount) AS revenue, 
DENSE_RANK() OVER (PARTITION BY city_id ORDER BY SUM(fare_amount) DESC) AS drnk,
CASE WHEN DENSE_RANK() OVER (PARTITION BY city_id ORDER BY SUM(fare_amount) DESC) = 1 THEN SUM(fare_amount) END AS max_rev
FROM fact_trips 
GROUP BY 1, 2
),
REV_CTE AS (
SELECT c.city_name, month, revenue, max_rev
FROM dim_city c JOIN CTE ON c.city_id = cte.city_id 
),
CONTRIBUTE_CTE AS (
SELECT *, ROUND(100 * max_rev/sum(revenue) OVER (PARTITION BY city_name),2) as contribution_pct
FROM REV_CTE 
)
SELECT city_name, month, max_rev as highest_revenue, contribution_pct
FROM CONTRIBUTE_CTE WHERE max_rev IS NOT NULL AND contribution_pct IS NOT NULL ;

/*Ad Hoc-6 Repeat Passenger Rate analysis */

/*RPR% city-wise */
SELECT c.city_name, sum(total_passengers), sum(repeat_passengers),
ROUND(100 * sum(repeat_passengers) / sum(total_passengers), 2) Repeat_pct_city_wise
FROM dim_city c JOIN fact_passenger_summary p 
ON c.city_id = p.city_id
GROUP BY 1;

/*RPR% monthly */
SELECT monthname(month) as Month, c.city_name, p.total_passengers, p.repeat_passengers,
ROUND(100 * repeat_passengers/total_passengers, 2) as repeat_pct_monthly
FROM dim_city c JOIN fact_passenger_summary p 
ON c.city_id = p.city_id ;




 
 
 
 
 
 
 
 

 
 