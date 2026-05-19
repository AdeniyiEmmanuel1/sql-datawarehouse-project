/*
===============================================================================================
BUILDING THE DIMENSION VIEWS  (GOLD LAYER)
===============================================================================================
Objectives:- 
			this provides Data to be consumed for reporting
Script Purpose:-
			This creates views for the gold layer in the datawarehouse. The gold layer represents
			the final dimension and fact table (Star Schema). Each views performs transformation
			and combines data from the cleaned silver layer to produce a clean, enriched and 
			business ready dataset.
Usage:-
		-	These views can be queried directly from analytics & reporting
=================================================================================================
*/
--- Building Dimension Views For Customers
CREATE VIEW gold.dim_customers AS
Select
		Row_Number() over(order by cst_id) Customer_key,
		ct.cst_id Customer_ID,
		ct.cst_key Customer_Number,
		ct.cst_firstname First_name,
		ct.cst_lastname Last_name,
		cn.CNTRY Country,
		ct.cst_marital_status Marital_status,
		CASE WHEN ct.cst_gndr != 'n/a' THEN ct.cst_gndr
		ELSE COALESCE(cd.GEN,'n/a')
		END Gender,
		ct.cst_create_date Create_date,
		cd.BDATE Birthdate
	From Silver.crm_cust_info ct
	LEFT JOIN Silver.erp_CUST_AZ12 cd
	ON ct.cst_key = cd.CID
	LEFT JOIN Silver.erp_LOC_A101 cn
	ON ct.cst_key = cn.CID;

--- Building Dimension Views For Products
CREATE VIEW gold.dim_products AS
Select 
	Row_Number() over(order by pd.prd_start_dt,pd.prd_key) Product_key,
	pd.prd_id Product_ID,
	pd.prd_key Product_number,
	pd.prd_nm Product_name,
	pd.cat_id Category_ID,
	px.CAT Category,
	px.SUBCAT Subcategory,
	px.MAINTENANCE Maintenance,
	pd.prd_cost Product_cost,
	pd.prd_line Product_line,
	pd.prd_start_dt Startdate
From Silver.crm_prd_info pd
LEFT JOIN Silver.erp_PX_CAT_G1V2 px
ON pd.cat_id = px.ID

--- Building Dimension Views For Sales
CREATE VIEW gold.dim_Sales AS
Select
ROW_NUMBER() over(Order by sa.sls_order_dt) Sales_key,
sa.sls_ord_num Order_Number,
pr.Product_number,
gd.Customer_ID,
sa.sls_order_dt Order_Date,
sa.sls_ship_dt Shipping_Date,
sa.sls_due_dt Due_Date,
sa.sls_sales Sales_Amount,
sa.sls_quantity Quantity,
sa.sls_price Price
From Silver.crm_sales_details sa
Left Join gold.dim_products pr
ON sa.sls_prd_key = pr.Product_number
Left Join gold.dim_customers gd
ON sa.sls_cust_id = gd.Customer_ID;
