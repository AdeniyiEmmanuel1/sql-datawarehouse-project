/* 
===============================================================================================
PRODUCT REPORT
===============================================================================================
Purpose:- 
			-This report consolidtes key products metrics and behaviours
Highlights:-
			1. Gathers essential field such as product name, category, subcategory and product cost
			2. segments products by revenue to identify High-Performers, Mid-Range and Low-Performers
			3. Aggregates product-level metrics:
			   - Total orders
			   - Total Sales
			   - Total quantity sold
			   - Total customers (unique)
			   - Lifespan (in months)
			4. Calcualtes valuable KPIs:
			   - recency (months since last sale)
			   - average order revenue
			   - average monthly revenue
=================================================================================================
*/

Create View gold.reports_products AS 

WITH base_query AS (
	Select 
	s.Order_Number,
	s.Order_Date,
	s.Customer_ID,
	s.Sales_Amount,
	s.Quantity,
	p.Product_key,
	p.Product_name,
	p.Category,
	p.Subcategory,
	p.Product_cost
	From Gold.dim_Sales s
	LEFT JOIN Gold.dim_products p
	ON s.Product_number = p.Product_number
	Where Order_Date IS NOT NULL
),
---- Product Aggregation: Summarizes key metrics at product level
Product_aggregation AS (
Select 
	Product_key,
	Product_name,
	Category,
	Subcategory,
	Product_cost,
	Count(Distinct Order_Number) Total_Orders,
	Sum(Sales_Amount) Total_Sales,
	Sum(Quantity) Total_Quantity,
	Count(Distinct Customer_ID) Total_Customers,
	Max(Order_Date) Last_Order,
	Min(Order_Date) First_Order,
	DATEDIFF(Month,Min(Order_Date),Max(Order_Date)) Lifespan,
	ROUND (AVG (CAST (Sales_Amount AS FLOAT)/ NULLIF (Quantity,0)),1) as Average_selling_Price
From base_query
Group By 
	Product_key,
	Product_name,
	Category,
	Subcategory,
	Product_cost)
	
---- Product Level Segmentation: Segmenting key metrics at product level
Select 
	Product_key,
	Product_name,
	Category,
	Subcategory,
	Product_cost,
	Case When Total_Sales > 150000 Then 'High Performer'
		When Total_Sales >= 100000 Then 'Mid-range Performer'
		Else 'Low Performer'
	End AS Product_Segments,
	Lifespan,
	Total_Sales,
	Total_Customers,
	Total_Quantity,
	Average_selling_Price,
	DateDiff (Month,Last_Order, GetDate()) Recency,
	------ average monthly revenue
	Case When Lifespan = 0 Then Total_Sales 
		Else Total_Sales / Lifespan
	End AS Avg_Monthly_Revenue,
	------ Average Order Revenue
	Case When Total_Orders = 0 Then Total_Sales 
		Else Total_Sales / Total_Orders
	End AS Avg_Order_Revenue
From Product_aggregation;


Select * 
From Gold.reports_products
