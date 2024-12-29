-- 1. Low-Demand Product Categories
-- Identify the three product categories with the lowest demand based on sales quantity.

select c.category_name, sum(oi.quantity) as total_sales_quantity from orders o
join order_items oi on o.order_id = oi.order_id
join products p on oi.product_id = p.product_id
join categories c on p.category_id = c.category_id
where o.shipped_date is not null
group by c.category_name
order by total_sales_quantity
limit 3;

-- 2. Store Performance in Footfall
-- Determine which store has the highest and lowest customer footfall based on the number of total customers visiting each store.

with overall_count as
(select s.store_id, s.store_name, s.city, count(*) as cnt from orders o
join stores s on o.store_id = s.store_id
where shipped_date is not null
group by s.store_id, s.store_name, s.city
order by cnt desc)
select
(select concat(store_name, " - ", cnt) from overall_count order by cnt desc limit 1) as highest_footfall_store,
(select concat(store_name, " - ", cnt) from overall_count order by cnt limit 1) as lowest_footfall_store
from overall_count
limit 1;

-- 3. Average Shipping Turnaround by Staff and Store
-- Calculate the average order-to-shipping time for each staff member and store.
with main as
(select sto.store_name, o.store_id,
concat(sta.first_name, " ", sta.last_name) as staff_name, 
o.staff_id,
round(avg(datediff(o.shipped_date, o.order_date)),2) as turnaround_days
from orders o
join stores sto on o.store_id = sto.store_id
join staffs sta on o.staff_id = sta.staff_id
where o.order_status = 4
group by 1, 2, 3, 4
order by turnaround_days),
stores as
(select store_name, store_id, round(avg(turnaround_days),2) as days from main
group by store_name, store_id)
select m.store_name, m.staff_name, m.turnaround_days as staff_turnaround, s.days as store_turnaround_days from main m 
join stores s on m.store_id = s.store_id;

-- 4. Brand Loyalty (gave my logic to chatgpt, which was correct, and then got the output)
-- Identify which brand has the most loyal customers, defined as customers who have made repeat purchases.
with repeat_customers as
(select o.customer_id, count(distinct o.order_date) as purchase_date
from orders o group by o.customer_id
having count(distinct o.order_date)>1),
customer_purchase as
(select rc.customer_id, o.order_date, b.brand_name
from orders o join repeat_customers rc on rc.customer_id = o.customer_id
join order_items oi on o.order_id = oi.order_id
join products p on oi.product_id = p.product_id
join brands b on p.brand_id = b.brand_id),
customer_loyalty as
(select customer_id, brand_name, count(*) as purchase_count, dense_rank() over (partition by customer_id order by count(*) desc) as rnk
from customer_purchase
group by customer_id, brand_name)
select brand_name, count(*) as loyal_customer from customer_loyalty
where rnk = 1
group by brand_name
order by loyal_customer desc;

-- 5. Top Purchasing City
-- Find the city where customers purchase the most products.
with most_products as
(select o.customer_id, count(o.order_id) as number_of_purchases from orders o
join order_items oi on o.order_id = oi.order_id
group by o.customer_id
order by 2 desc)
select c.city, c.state, sum(mp.number_of_purchases) as most_purchases from most_products mp
join customers c on mp.customer_id = c.customer_id
group by c.city, c.state
order by 3 desc;

-- 6. Average Order Value by Store
-- Calculate the average order value for each store.
with total_order_value as
(select s.store_id, s.store_name, round(sum(oi.quantity*oi.list_price - ((oi.quantity*oi.list_price)*oi.discount)),2) as total_order_value from order_items oi
join orders o on oi.order_id = o.order_id
join stores s on o.store_id = s.store_id
group by s.store_id, s.store_name),
total_orders as
(select s.store_id, count(oi.order_id) as total_number_of_orders from order_items oi
join orders o on oi.order_id = o.order_id
join stores s on o.store_id = s.store_id
group by s.store_id)
select toto.store_id, tov.store_name, round((tov.total_order_value/toto.total_number_of_orders),2) as avg_order_value
from total_order_value tov
join total_orders toto on tov.store_id = toto.store_id
order by 3 desc;

-- 7. Top Sales Staff
-- Retrieve the contact numbers of the top 3 sales staff based on total revenue generated.
select s.staff_id, concat(s.first_name, " ", s.last_name)as name,  s.phone, round(sum(oi.quantity*oi.list_price - ((oi.quantity*oi.list_price)*oi.discount)),2) as rev_generated from order_items oi
join orders o on oi.order_id = o.order_id
join staffs s on o.staff_id = s.staff_id
where o.shipped_date is not null
group by s.staff_id, s.first_name, s.last_name, s.phone
order by rev_generated desc, name
limit 3;

-- 8. Frequent Buyers
-- Get the details of the customers who have made the most purchases.
select c.customer_id, c.first_name, c.last_name, c.email, c.street, c.city, c.state, c.zip_code, count(distinct oi.order_id) as shopping_frequency from customers c 
join orders o on c.customer_id = o.customer_id
join order_items oi on o.order_id = oi.order_id
group by c.customer_id, c.first_name, c.last_name, c.email, c.street, c.city, c.state, c.zip_code
having shopping_frequency > 1
order by shopping_frequency desc;

-- 9. Product Discontinuation
-- Identify products that consistently perform poorly in terms of sales quantity and revenue. Should these products be discontinued?
select p.product_name, 
sum(oi.quantity) as total_quantity_sold,
round(sum(oi.quantity*oi.list_price - ((oi.quantity*oi.list_price)*oi.discount)),2) as total_revenue_generated from products p
join order_items oi on p.product_id = oi.product_id
join orders o on oi.order_id = o.order_id
where o.shipped_date is not null
group by p.product_name
having total_quantity_sold < 5 and total_revenue_generated < 5000
order by 3, 2;

-- 10. Best-Selling Products
-- Rank all products based on the total quantity sold.
with quantity_sold as
(select p.product_name,
sum(oi.quantity) as total_quantity_sold
from products p
join order_items oi on p.product_id = oi.product_id
join orders o on oi.order_id = o.order_id
where o.shipped_date is not null
group by p.product_name)
select *, dense_rank() over (order by total_quantity_sold desc) as ranking 
from quantity_sold
order by ranking;

-- 11. Store Revenue Contribution
-- Rank stores based on their contribution to overall revenue, and determine the percentage contribution of each store.
with store_revenue as
(select s.store_id, s.store_name, round(sum(oi.list_price*oi.quantity-(oi.list_price*oi.quantity)*oi.discount),2) as store_revenue from order_items oi
join orders o on oi.order_id = o.order_id
join stores s on o.store_id = s.store_id
where o.shipped_date is not null
group by s.store_id, s.store_name),
total_revenue as
(select *, round(sum(store_revenue) over(),2) as total_revenue from store_revenue),
contribution as
(select *, round((store_revenue*100/total_revenue),2) as percentage_contribution
from total_revenue)
select *, rank() over (order by percentage_contribution desc) as ranking from contribution
order by ranking;

-- 12. Customer Retention Analysis
-- Analyze which store has the highest customer retention rate based on customers making multiple purchases.
with unique_customers as
(select s.store_id, s.store_name, count(distinct customer_id) as uni_customers from order_items oi
join orders o on oi.order_id = o.order_id
join stores s on o.store_id = s.store_id
where o.shipped_date is not null
group by s.store_id, s.store_name),
second_purchase as
(select s.store_id, s.store_name, count(distinct o.order_date) as order_cnt
from order_items oi
join orders o on oi.order_id = o.order_id
join stores s on o.store_id = s.store_id
where o.shipped_date is not null
group by s.store_id, s.store_name
having order_cnt > 1)
select sp.store_id, sp.store_name, uc.uni_customers, sp.order_cnt, round((sp.order_cnt*100/uc.uni_customers),2) as retention_percentage 
from second_purchase sp
join unique_customers uc on sp.store_id = uc.store_id
group by sp.store_id, sp.store_name, uc.uni_customers, sp.order_cnt
order by retention_percentage desc;

-- 13. Category Revenue Trends
-- Identify which product category has shown the highest revenue growth over the past year.
with 2016_rev as
(select c.category_id, c.category_name, round(sum(oi.quantity * oi.list_price - ((oi.quantity * oi.list_price)*oi.discount)),2) as 2016_revenue from orders o
join order_items oi on o.order_id = oi.order_id
join products p on oi.product_id = p.product_id
join categories c on p.category_id = c.category_id
where o.shipped_date is not null
and year(o.order_date) = 2016
group by c.category_id, c.category_name),
2017_rev as
(select c.category_id, c.category_name, round(sum(oi.quantity * oi.list_price - ((oi.quantity * oi.list_price)*oi.discount)),2) as 2017_revenue from orders o
join order_items oi on o.order_id = oi.order_id
join products p on oi.product_id = p.product_id
join categories c on p.category_id = c.category_id
where o.shipped_date is not null
and year(o.order_date) = 2017
group by c.category_id, c.category_name)
select ei.category_id, ei.category_name, 2016_revenue, 2017_revenue, round((2017_revenue - 2016_revenue)*100/2016_revenue,2) as growth_percentage from 2017_rev ei
join 2016_rev se on ei.category_id = se.category_id
order by growth_percentage desc;

-- 14. Cross-Selling Opportunities (USED CHATGPT FOR HELP)
-- Identify products that are frequently purchased together, and suggest cross-selling opportunities.
with product_pairs as
(select oi1.product_id as product_1, 
oi2.product_id as product_2, 
count(*) as purchase_count
from order_items oi1 
join order_items oi2 
on oi1.order_id = oi2.order_id
and oi1.product_id < oi2.product_id
group by oi1.product_id, oi2.product_id),
frequent_pairs as
(select product_1, product_2, purchase_count
from product_pairs
where purchase_count > 5)
select p1.product_name as prod_1, p2.product_name as prod_2, fp.purchase_count
from products p1 
join frequent_pairs fp on p1.product_id = fp.product_1
join products p2 on p2.product_id = fp.product_2
order by 3 desc;

-- 15. Revenue per Staff Member
-- Calculate the total and average revenue generated by each staff member, including their rank in terms of sales performance.
with total_rev as
(select s.staff_id, concat(s.first_name, " ", s.last_name)as name,  s.phone, round(sum(oi.quantity*oi.list_price - ((oi.quantity*oi.list_price)*oi.discount)),2) as rev_generated from order_items oi
join orders o on oi.order_id = o.order_id
join staffs s on o.staff_id = s.staff_id
where o.shipped_date is not null
group by s.staff_id, s.first_name, s.last_name, s.phone),
avg_rev as
(select s.staff_id, concat(s.first_name, " ", s.last_name)as name,  s.phone, round(avg(oi.quantity*oi.list_price - ((oi.quantity*oi.list_price)*oi.discount)),2) as avg_rev_generated from order_items oi
join orders o on oi.order_id = o.order_id
join staffs s on o.staff_id = s.staff_id
where o.shipped_date is not null
group by s.staff_id, s.first_name, s.last_name, s.phone)
select ar.staff_id, 
ar.name, ar.phone, 
tr.rev_generated as total_revenue, 
ar.avg_rev_generated as average_revenue,
rank() over (order by tr.rev_generated desc) as sales_performance_ranking
from total_rev tr join avg_rev ar on tr.staff_id = ar.staff_id
order by sales_performance_ranking;

-- 16. Seasonal Sales Patterns
-- Analyze the monthly sales trends for each store and determine which month generates the highest sales.
select year(o.order_date) as year, monthname(o.order_date) as month, round(sum(oi.quantity*oi.list_price - ((oi.quantity*oi.list_price)*oi.discount)),2) as sales from orders o
join order_items oi on o.order_id = oi.order_id
where o.shipped_date is not null
group by year, month
order by 3 desc;

-- 17. Stock Efficiency
-- Identify stores where the stock-to-sales ratio is too high, indicating overstocking issues.
with base as
(select s.store_id,
sum(s.quantity) as stock_quantity,
sum(oi.quantity) as sale_quantity
from stocks s
join orders o on s.store_id = o.store_id
join order_items oi on o.order_id = oi.order_id
where o.shipped_date is not null
group by s.store_id)
select store_id, stock_quantity, sale_quantity, round((stock_quantity/nullif(sale_quantity,0)),2) as stock_to_sales_ratio from base;

-- 18. High-Value Customers
-- Identify the top 10 customers who contribute the most revenue to the business and their associated cities.
with spend as
(select o.customer_id, round(sum(oi.quantity*oi.list_price - ((oi.quantity*oi.list_price)*oi.discount)),2) as customer_spend from orders o
join order_items oi on o.order_id = oi.order_id
where o.shipped_date is not null
group by o.customer_id)
select 
s.customer_id, concat(c.first_name, " ", c.last_name) as name, c.city, c.state, s.customer_spend
from spend s
join customers c on s.customer_id = c.customer_id
order by 5 desc
limit 10;

-- 19. Profitability of Brands
-- Rank all brands based on their profitability by calculating total revenue minus average product discounts.
select b.brand_id, b.brand_name, round(sum(oi.quantity*oi.list_price - ((oi.quantity*oi.list_price)*oi.discount)),2) as profit,
rank() over (order by round(sum(oi.quantity*oi.list_price - ((oi.quantity*oi.list_price)*oi.discount)),2)desc) as rnk from orders o
join order_items oi on o.order_id = oi.order_id
join products p on oi.product_id = p.product_id
join brands b on p.brand_id = b.brand_id
where o.shipped_date is not null
group by b.brand_id, b.brand_name;

-- 20. Underperforming Stores
-- Identify stores with the lowest sales growth over the past year and recommend potential action plans.
with 2016_rev as
(select s.store_id, s.store_name, round(sum(oi.quantity * oi.list_price - ((oi.quantity * oi.list_price)*oi.discount)),2) as 2016_revenue from order_items oi
join orders o on oi.order_id = o.order_id
join stores s on o.store_id = s.store_id
where o.shipped_date is not null
and year(o.order_date) = 2016
group by s.store_id, s.store_name),
2017_rev as
(select s.store_id, s.store_name, round(sum(oi.quantity * oi.list_price - ((oi.quantity * oi.list_price)*oi.discount)),2) as 2017_revenue from order_items oi
join orders o on oi.order_id = o.order_id
join stores s on o.store_id = s.store_id
where o.shipped_date is not null
and year(o.order_date) = 2017
group by s.store_id, s.store_name)
select ei.store_id, ei.store_name, 2016_revenue, 2017_revenue, round((2017_revenue - 2016_revenue)*100/2016_revenue,2) as growth_percentage from 2017_rev ei
join 2016_rev se on ei.store_id = se.store_id
order by growth_percentage desc;














































