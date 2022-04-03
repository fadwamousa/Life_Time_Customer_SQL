--Finding First order by Customer
--and all data about orders (Just one Customer)
select * from payment p

select p.* from payment p INNER JOIN 
(
select payment.customer_id , min(payment.payment_date) Min_Order_Date from payment 
group by payment.customer_id
) P2
ON p.payment_date = p2.Min_Order_Date
order by P2.customer_id ASC

---------------------------------------------------------------------
SELECT * FROM (
select p.*,ROW_NUMBER() over(partition by p.customer_id order by p.payment_date) RN from payment p
)AS X 
WHERE RN = 1 
------------------------------------------------------------------------------
--Analyzing New Versus Repeat Buyer Behavior

SELECT *,
       CASE WHEN RN = 1 THEN 'First Order'
	        WHEN RN > 1 THEN 'Repeat Order'
       END AS 'Buyer Behavior'
FROM (
select p.*,
ROW_NUMBER() over(partition by p.customer_id order by p.payment_date) RN 
FROM payment p
)AS X 
order by customer_id asc
-------------------------------------------------------------------------------------------------------
--Customer Value Analysis (LVT)

WITH Base_table as 
(
select p.customer_id,p.payment_date,amount,
ROW_NUMBER() over(partition by p.customer_id order by p.payment_date) Rn_Asc , --First_Order
ROW_NUMBER() over(partition by p.customer_id order by p.payment_date DESC) Rn_Desc -- Last_Order
FROM payment p
),
Second_table as (
select * from Base_table bt where Rn_ASC = 1 OR Rn_Desc = 1
)

select st.customer_id,min(st.payment_date) , max(st.payment_date) , 
(SELECT sum(p2.amount) FROM payment p2) as Total_spent_for_all_customers,
(SELECT sum(p2.amount) from payment p2 where st.customer_id = p2.customer_id) as total_spent_per_customer_LVT
FROM Second_table st
group by st.customer_id
------------------------------------------------------------------------------------------------------------------

--Perfered rating (need to figure out how to get their rating)
--This give you all films that rented in rental table
SELECT * FROM (
	SELECT t.customer_id,t.rating,count(*) number_rows ,
		   ROW_NUMBER() over(partition by t.customer_id order by count(*) desc) as rn
	 FROM (
	select r.rental_id,r.customer_id,r.inventory_id , i.film_id , f.rating 
				  FROM rental r
				  INNER JOIN 
				  inventory i 
				  on r.inventory_id = i.inventory_id
				  INNER JOIN 
				  film f
				  on f.film_id = i.film_id
	) t 

	group by t.customer_id,t.rating
	--order by 1 , 3 DESC

) t2
where t2.rn = 1
order by 1 , 3 DESC
---------------------------------------------------------------------------------------------------
SELECT (ABS(DATEDIFF(SECOND,x.payment_date,x.Pervious_Date))) / 3600   as hoursBetween--, 
       --DATEDIFF(year,x.payment_date,x.Pervious_Date) as  Years_Between
FROM (
select p.* , lag(p.payment_date) over(order by payment_date asc) as Pervious_Date  from payment p
) 
as X
-----------------------------------------------------------------------------------------------------------
--Rolling Avg 

---Rolling Avg for 7 sales day (Last 7 row avg)
select p.*, 
avg(p.amount) over(order by p.payment_id rows between 7 preceding and 0 following) as Avg_Over_Prior_7days,
avg(p.amount) over(order by p.payment_id rows between 3 preceding and 7 following) as Avg_Over_Prior_3days
FROM payment p 

-----------------------------------------------------------------------------------------
GO
WITH Bs_tabel as 
(
    SELECT * FROM (
		select p.payment_id,p.customer_id,p.payment_date,p.rental_id,amount,
		ROW_NUMBER() over(partition by p.customer_id order by p.payment_date) RN 
		FROM payment p 
	) t WHERE t.RN = 1 
)
-->Rental -->Inventory -->Films
select t.rating,count(*),t.rating,sum(t.amount) as Total_amount_Spent from ( 
select bs.payment_id,r.*,f.*,bs.amount
						 FROM  Bs_tabel bs 
						 INNER JOIN rental     r on r.rental_id    = bs.rental_id
						 INNER JOIN inventory  i on i.inventory_id = r.inventory_id
						 INNER JOIN film       f on f.film_id      = i.film_id
) t group by t.rating
------------------------------------------------------------------------------------
--Get films by highest gross revenue per actor
select * from film
select * from film_actor
--Number of actors for each film
select count(*) as Number_actor , f.film_id FROM film_actor fa 
                inner join 
				film f 
				on fa.film_id = f.film_id
group by f.film_id
---------------------------------------------------------------------------------------

--Finding the top five highest gross revenue per actor 
--what % of customer rented from one of their films
/*
  1-Get a table of actors and rental revenue per actor
  2-Get top 5 of highest of revenue
  3-Get all film actors appeared in
  4-Find out how many customers rented from all customers
*/
GO
With cte as (
select distinct p.amount amount_x,r.inventory_id,f.film_id,
                p.amount,a.first_name + ' ' + a.last_name as Actor_Name,
				a.actor_id actor_id
						 FROM  payment p 
						 INNER JOIN rental     r  on r.rental_id    = p.rental_id
						 INNER JOIN inventory  i  on i.inventory_id = r.inventory_id
						 INNER JOIN film       f  on f.film_id      = i.film_id
						 inner Join film_actor fa on fa.film_id    = f.film_id
						 inner join actor      a  on a.actor_id    =fa.actor_id
),
top5 as
(select top 5 sum(amount_x) Sum_Amount,Actor_Name, actor_id from cte
group by Actor_Name,actor_id
order by Sum_Amount desc),
movie_top as (
select distinct fa.film_id from film_actor fa where actor_id in (select actor_id from top5) )


--select * from movie_top
--select count(distinct customer_id) from customer --599 customers 
select distinct t.customer_id from (
select distinct p.amount amount_x,p.customer_id,r.inventory_id,f.film_id
						 FROM  payment p 
						 INNER JOIN rental     r  on r.rental_id    = p.rental_id
						 INNER JOIN inventory  i  on i.inventory_id = r.inventory_id
						 INNER JOIN film       f  on f.film_id      = i.film_id
) t where t.film_id in (select film_id from movie_top)	--only 595 customers rented to these top films by highest gross revenu


