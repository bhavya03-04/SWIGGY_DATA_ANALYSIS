SELECT * FROM swiggy_data


-- Data cleaning and validation
-- Null values check in each column


SELECT 
    SUM(CASE WHEN state IS NULL THEN 1 ELSE 0 END) AS null_state,
    SUM(CASE WHEN city IS NULL THEN 1 ELSE 0 END) AS null_city,
    SUM(CASE WHEN order_date IS NULL THEN 1 ELSE 0 END) AS null_date,
    SUM(CASE WHEN restaurant_name IS NULL THEN 1 ELSE 0 END) AS null_restaurant,
    SUM(CASE WHEN location IS NULL THEN 1 ELSE 0 END) AS null_location,
    SUM(CASE WHEN category IS NULL THEN 1 ELSE 0 END) AS null_category,
    SUM(CASE WHEN dish_name IS NULL THEN 1 ELSE 0 END) AS null_dish,
    SUM(CASE WHEN price_INR IS NULL THEN 1 ELSE 0 END) AS null_price,
    SUM(CASE WHEN rating IS NULL THEN 1 ELSE 0 END) AS null_rating,
    SUM(CASE WHEN rating_count IS NULL THEN 1 ELSE 0 END) AS null_rating_count
FROM swiggy_data;


-- Empty Strings

SELECT * FROM swiggy_data
WHERE State = '' 
   OR City = '' 
   OR Restaurant_Name = '' 
   OR Location = '' 
   OR Category = '' 
   OR Dish_Name = '';
   
-- Identifying duplications

SELECT 
State, City, Order_Date, Restaurant_Name, Location, Category, Dish_Name, Price_INR, Rating, Rating_Count,
COUNT(*) as CNT
FROM swiggy_data
GROUP BY 
State, City, Order_Date, Restaurant_Name, Location, Category, Dish_Name, Price_INR, Rating, Rating_Count
HAVING COUNT(*) > 1;

-- Duplicate Removal 
WITH CTE AS (
    SELECT *, ROW_NUMBER() OVER (
        PARTITION BY State, City, Order_Date, Restaurant_Name, Location, Category, Dish_Name, Price_INR, Rating, Rating_Count 
        ORDER BY (SELECT NULL)) AS RN
    FROM swiggy_data
)
DELETE FROM CTE WHERE RN > 1;


-- Creating Schema
-- Dimension Tables 
-- Date Table
CREATE TABLE dimdate (
    date_id INT IDENTITY(1,1) PRIMARY KEY,
    full_date DATE,
    year INT,
    month INT,
    month_name VARCHAR(20),
    quarter INT,
    day INT,
    week  INT
    )



    -- Location Dimension
CREATE TABLE dimlocation (
    location_id INT IDENTITY(1,1) PRIMARY KEY,
    state VARCHAR(100),
    city VARCHAR(100),
    location VARCHAR(200)
);


-- Restaurant Dimension 
CREATE TABLE dim_restaurant (
    restaurant_id INT IDENTITY(1,1) PRIMARY KEY,
    restaurant_name VARCHAR(255)
);
-- Category Dimension 
CREATE TABLE dim_category (
    category_id INT IDENTITY(1,1) PRIMARY KEY,
    category VARCHAR(100)
);
-- Dish Dimension
CREATE TABLE dim_dish (
    dish_id INT IDENTITY(1,1) PRIMARY KEY,
    dish_name VARCHAR(200)
);

select * From swiggy_data

-- Fact Table
CREATE TABLE fact_swiggy_orders (
    order_id INT IDENTITY(1,1) PRIMARY KEY,
    date_id INT,
    price DECIMAL(10,2),
    rating DECIMAL(4,2),
    rating_count INT,
    location_id INT,
    restaurant_id INT,
    category_id INT,
    dish_id INT,

    FOREIGN KEY (date_id) REFERENCES dim_date(date_id),
    FOREIGN KEY (location_id) REFERENCES dim_location(location_id),
    FOREIGN KEY (restaurant_id) REFERENCES dim_restaurant(restaurant_id),
    FOREIGN KEY (category_id) REFERENCES dim_category(category_id),
    FOREIGN KEY (dish_id) REFERENCES dim_dish(dish_id),
   
);

Select * from fact_swiggy_orders

-- Insert Data in Tables
-- dim_date
INSERT INTO dim_date (full_date, year, month, month_name, quarter, day, week_number)
SELECT DISTINCT order_date, YEAR(order_date), MONTH(order_date), 
       DATENAME(MONTH, order_date), DATEPART(QUARTER, order_date), 
       DAY(order_date), DATEPART(WEEK, order_date)
FROM swiggy_data WHERE order_date IS NOT NULL;


Select * from dim_date


--dim_location
INSERT INTO dim_location (state, city, location)
SELECT DISTINCT state, city, location
FROM swiggy_data;


--dim_restaurant
INSERT INTO dim_restaurant (restaurant_name)
SELECT DISTINCT restaurant_name
FROM swiggy_data;

--dim_category
INSERT INTO dim_category (category)
SELECT DISTINCT category
FROM swiggy_data;

--dim_dish
INSERT INTO dim_dish (dish_name)
SELECT DISTINCT dish_name
FROM swiggy_data;

INSERT INTO fact_swiggy_orders (
    date_id, 
    price, 
    rating, 
    rating_count, 
    location_id, 
    restaurant_id, 
    category_id, 
    dish_id
)
SELECT 
    dd.date_id, 
    s.price_INR, 
    s.rating, 
    s.rating_count, 
    dl.location_id, 
    dr.restaurant_id, 
    dc.category_id, 
    ds.dish_id
FROM swiggy_data s
-- Joining with Dimension Tables to fetch the newly generated IDs
JOIN dim_date dd ON s.order_date = dd.full_date
JOIN dim_location dl ON s.state = dl.state 
    AND s.city = dl.city 
    AND s.location = dl.location
JOIN dim_restaurant dr ON s.restaurant_name = dr.restaurant_name
JOIN dim_category dc ON s.category = dc.category
JOIN dim_dish ds ON s.dish_name = ds.dish_name ;

Select * from fact_swiggy_orders

--KPIs
-- Total order
Select count(*) as Total_Orders
From fact_swiggy_orders

--Total Revenue in Millions
SELECT FORMAT(CONVERT(FLOAT, SUM(Price)) / 1000000, 'N2') + ' INR Million' AS total_revenue
FROM fact_swiggy_orders;

--Average rating
select 
avg(Rating) as Avg_Rating
from fact_swiggy_orders

-- Monthly Order Trends (Joining Fact and Date Dimension):
SELECT d.year, d.month, d.month_name, COUNT(*) AS total_orders
FROM fact_swiggy_orders f
JOIN dim_date d ON f.date_id = d.date_id
GROUP BY d.year, d.month, d.month_name
ORDER BY total_orders DESC;

--Quarterly Trend Analysis

SELECT 
    d.year,
    d.quarter,
    COUNT(f.order_id) AS total_orders,
    FORMAT(SUM(f.price) / 1000000, 'N2') + ' Million' AS total_revenue_INR
FROM fact_swiggy_orders f
JOIN dim_date d ON f.date_id = d.date_id
GROUP BY d.year, d.quarter
ORDER BY d.year, d.quarter;

--Yearly Trend Analysis

SELECT 
    d.year, 
    COUNT(f.order_id) AS total_orders,
    FORMAT(SUM(f.price) / 1000000, 'N2') + ' Million' AS total_revenue_INR
FROM fact_swiggy_orders f
JOIN dim_date d ON f.date_id = d.date_id
GROUP BY d.year
ORDER BY d.year;

--Day of the Week Trend

SELECT 
    DATENAME(WEEKDAY, d.full_date) AS day_of_week, 
    COUNT(f.order_id) AS total_orders
FROM fact_swiggy_orders f
JOIN dim_date d ON f.date_id = d.date_id
GROUP BY DATENAME(WEEKDAY, d.full_date), DATEPART(WEEKDAY, d.full_date)
ORDER BY DATEPART(WEEKDAY, d.full_date);

-- Top 10 Cities by Order Volume
SELECT TOP 10 l.city, COUNT(*) AS total_orders
FROM fact_swiggy_orders f
JOIN dim_location l ON f.location_id = l.location_id
GROUP BY l.city
ORDER BY total_orders DESC;

-- Revenue contribution by states
Select 
1.state,(f.price) as Total_Revenue from fact_swiggy_orders f
join dim_location l
ON l.location_id = f.location_id
GROUP BY l.state
ORDER BY sum(f.price) DESC


--Customer Spending Segments (Bucket Analysis):
SELECT 
    CASE 
        WHEN price < 100 THEN 'Under 100'
        WHEN price BETWEEN 100 AND 199 THEN '100-199'
        WHEN price BETWEEN 200 AND 299 THEN '200-299'
        WHEN price BETWEEN 300 AND 399 THEN '300-399'
        WHEN price BETWEEN 400 AND 499 THEN '400-499'
        ELSE '500+' 
    END AS spend_bucket,
    COUNT(*) AS total_orders
FROM fact_swiggy_orders
GROUP BY 
    CASE 
        WHEN price < 100 THEN 'Under 100'
        WHEN price BETWEEN 100 AND 199 THEN '100-199'
        WHEN price BETWEEN 200 AND 299 THEN '200-299'
        WHEN price BETWEEN 300 AND 399 THEN '300-399'
        WHEN price BETWEEN 400 AND 499 THEN '400-499'
        ELSE '500+' 
    END
Order by total_orders DESC;

-- rating count distribution (1-5)
Select 
    rating,
    count(*) as rating_count
From fact_swiggy_orders
Group by rating
Order by count(*) Desc;




 
