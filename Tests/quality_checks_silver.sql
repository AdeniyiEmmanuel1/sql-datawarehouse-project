/*
=========================================================================================================================
Quality checks
=========================================================================================================================
Script Purpose:
  This Script performs various quality checks for data consistency, accurcy, and standardization across the silver schema
It includes checks for:
  - Null or duplicate primary keys.
  - Unwanted spaces in string fields.
  - Data standidization and consistency
  - Invalid dat ranges and orders
  - Data consistency between related fields

Usage Notes: 
  - Run these checks after data loading silver layer
  ' Investigate and resolve discrepancies found in the checks.
=========================================================================================================================
*/

/*======================================
Data Cleaning Process
========================================*/

/*--------------------------------------- 
Checking for Duplicates
-----------------------------------------*/
Select *
From (
	Select 
		*, 
		ROW_NUMBER() OVER(PARTITION BY cst_id ORDER BY cst_create_date DESC) Flag_dup
		From Silver.crm_cust_info) t
Where cst_id IS NULL and Flag_dup > 1

Select 
	cst_id,
	count(*)
	From Silver.crm_cust_info
	Group by cst_id
	Having count(*) >1 or cst_id IS NULL

Select
	ID,
	count(*)
	From Bronze.erp_PX_CAT_G1V2
	Group by ID
	Having count(*) >1 or ID IS NULL;

Select *
From (
	Select 
		*, 
		ROW_NUMBER() OVER(PARTITION BY cst_key ORDER BY cst_create_date DESC) Flag_dup
		From Bronze.crm_cust_info) t
Where cst_key IS NOT NULL and Flag_dup = 1

Select 
*
From (
	Select 
		*, 
		ROW_NUMBER() OVER(PARTITION BY  CID ORDER BY BDATE DESC) Flag_dup
		From Bronze.erp_CUST_AZ12) t
Where CID  IS NULL and Flag_dup > 1

/*--- Checking if the primary key matches connecting table ----*/
select
sls_prd_key
From Bronze.crm_sales_details
Where sls_prd_key NOT IN 
(Select
	prd_key
From Silver.crm_prd_info)

--- Cleaning the Primary of table a to match primary key of table b
Select
CID,
Case When CID LIKE 'NAS%' THEN SUBSTRING(CID,4,LEN(CID)) ELSE CID  END CID
From Bronze.erp_CUST_AZ12
 


/*--------------------------------------- 
Checking for Unwanted spaces
-----------------------------------------*/
Select 
	prd_key
From Bronze.crm_prd_info
where prd_key != TRIM(prd_key)

Select 
	CID
From Bronze.erp_CUST_AZ12
where CID != TRIM(CID)

/*--------------------------------------- 
Checking for Consistency
-----------------------------------------*/
Select distinct
	cst_key
From Silver.crm_cust_info
where cst_key NOT LIKE 'AW%'

Select distinct
cst_firstname
From Silver.crm_cust_info
where cst_firstname != TRIM(cst_firstname)

Select 
	prd_key
From Bronze.crm_prd_info
where prd_key != TRIM(prd_key)

/* Using the replace function for data consistency*/
Select 
prd_key,
REPLACE(SUBSTRING(prd_key,1,5),'-','_') AS Cat_ID,
SUBSTRING(prd_key,7,LEN(prd_key)) prd_key ---- This is to extract the remaining string from position 7
From Bronze.crm_prd_info

/*--------------------------------------- 
Checking for Consistency/Standardization
-----------------------------------------*/
Select distinct 
prd_line
From Silver.crm_prd_info

Select 
	cst_marital_status,
	cst_gndr,
	CASE WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
		WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
		ELSE 'n/a'
	END cst_marital_status,
	CASE WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
		WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
		ELSE 'n/a'
	END cst_gndr
From bronze.crm_cust_info


Select
prd_line,
CASE UPPER(TRIM(prd_line))
	WHEN 'M' THEN 'Mountain' ------ We only use this short form of case statement when it is just mapping we are doing
	WHEN 'R' THEN 'Road'
	WHEN 'S' THEN 'Other Sales'
	WHEN 'T' THEN 'Touring'
ELSE 'n/a'
END prd_line
From Bronze.crm_prd_info

/*====================================================== 
Checking for Date Structure
========================================================*/

SELECT
  *
FROM Bronze.crm_prd_info
----Where prd_start_dt IS NULL
WHERE TRY_CONVERT(DATE,  prd_start_dt) IS NULL;

----Checking Birthdate error if its greater than present date or lesser than outrageous date
Select BDATE
From Bronze.erp_CUST_AZ12
Where BDATE < '1924-01-01' or BDATE > GETDATE() 

Select BDATE, 
CASE WHEN BDATE > GETDATE() 
THEN NULL 
ELSE BDATE 
END BDATE------ WE ARE ONLY REMOVING THE ONE WE ARE SURE OF SINCE BIRTHDAY CANNOT BE GREATER THAN PRESENT DATE 
From Bronze.erp_CUST_AZ12

/* Correcting Date Structure 
Start Date must be earlier than end date*/

SELECT
prd_start_dt,
CAST(prd_start_dt AS DATE) prd_start_dt,
CAST(LEAD(prd_start_dt) OVER(PARTITION BY prd_key ORDER BY prd_start_dt-1) AS DATE) prd_end_dt---- this is to derive an end date of the record from the start date of the next record
FROM Bronze.crm_prd_info

/* changing the structure of date for improper date structures e.g 20250605*/
Select 
sls_order_dt,
sls_sales,
sls_quantity,
sls_price,
CASE WHEN sls_order_dt = 0 or LEN(sls_order_dt) != 8 or sls_order_dt > 20500101 or sls_order_dt < 19000101 THEN NULL
	ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE)
	END sls_order_dt,
CASE WHEN sls_ship_dt = 0 or LEN(sls_ship_dt) != 8 THEN NULL
	ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE)
	END sls_ship_dt,
CASE WHEN sls_due_dt = 0 or LEN(sls_due_dt) != 8 THEN NULL
	ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)
	END sls_due_dt,
CASE WHEN sls_sales != sls_quantity * ABS(sls_price) 
	or sls_sales IS NULL 
	or sls_sales <= 0 THEN sls_quantity*ABS(sls_price)
	ELSE sls_sales
	END sls_sales,
CASE WHEN sls_price <=0 or sls_price IS NULL 
	THEN sls_sales/NULLIF(sls_quantity,0)
	ELSE sls_price
	END sls_price
From Bronze.crm_sales_details
where sls_quantity > 1


Select *
From Silver.crm_sales_details
Where sls_sales != sls_quantity * ABS(sls_price) 
	or sls_sales IS NULL 



