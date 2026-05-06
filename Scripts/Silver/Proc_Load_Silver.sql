/*
===================================================================================================================
STORED PROCEDURE: Loading the Silver layer from the bronze layer
===================================================================================================================
Purpose
  This stored procedure performs ETL (Extract, Transform, Load) process to populate the 'silver' schema tables from 
  the 'bronze' schema.
Actions Performed:
  - Truncates Silver Tables
  - Inserts transformed and cleansed data from Bronze into Silver Layer
Parameters:
  None
  This Stored Procedure does not accept any parameters or return any values.
Usage Example:
  EXEC Silver.load_Silver;
=====================================================================================================================
*/



CREATE or ALTER PROCEDURE Silver.load_Silver
AS
DECLARE @Start_Time DATETIME, @End_Time DATETIME, @Batch_Start_Time DATETIME, @Batch_End_Time DATETIME; --------- This is to declare variables @Start_Time and @End_Time to calculate duration
BEGIN
    
	BEGIN TRY ------------- To check for errors running the script
	SET @Batch_Start_Time = GETDATE()
	PRINT'================================================================================================================='
	PRINT'Loading Silver Layer';
	PRINT'================================================================================================================='

	PRINT'-----------------------------------------------------------------------------------------------------------------'
	PRINT'Loading CRM Tables';
	PRINT'-----------------------------------------------------------------------------------------------------------------'

	SET @Start_Time = GETDATE();

	PRINT'>>>Truncating Table: Silver.crm_cust_info';

	TRUNCATE TABLE Silver.crm_cust_info;
	PRINT'>> Inserting Data Into Silver.crm_cust_info'
	INSERT INTO Silver.crm_cust_info 
	(cst_id,
	cst_key,
	cst_firstname,
	cst_lastname,
	cst_marital_status,
	cst_gndr,
	cst_create_date
	)
	Select 
		cst_id,
		cst_key, 
		TRIM(cst_firstname) AS cst_firstname, 
		TRIM(cst_lastrname) AS cst_lastname,
		CASE WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
			WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
			ELSE 'n/a'
		END cst_marital_status,
		CASE WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
			WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
			ELSE 'n/a'
		END cst_gndr, 
		cst_create_date
	From (
		Select 
			*, 
		ROW_NUMBER() OVER(PARTITION BY cst_id ORDER BY cst_create_date DESC) Flag_dup
		From Bronze.crm_cust_info) t
	Where cst_id IS NOT NULL and cst_key LIKE 'AW%' and Flag_dup = 1 and TRY_CONVERT(DATE, cst_create_date) IS NOT NULL

	 SET @End_Time = GETDATE();
		PRINT'>> load Duration:' + CAST(DATEDIFF(second,@Start_Time,@End_Time) AS NVARCHAR) + ' seconds'
		PRINT'>> ---------------------------------------------------------'

	/*============================================================
	Cleaning and Loading the product table
	=============================================================*/
	SET @Start_Time = GETDATE ();
		PRINT'>>>Truncating Table: Silver.crm_prd_info';

	TRUNCATE TABLE Silver.crm_prd_info;
	PRINT'>> Inserting Data Into Silver.crm_prd_info'
	Insert Into Silver.crm_prd_info
	(
	prd_id,
	cat_id,
	prd_key,
	prd_nm,
	prd_cost,
	prd_line,
	prd_start_dt,
	prd_end_dt
	)
	Select
		prd_id,
		REPLACE(SUBSTRING(prd_key,1,5),'-','_') AS cat_id,
		SUBSTRING(prd_key,7,LEN(prd_key)) prd_key, ---- This is to extract the remaining string from position 7
		prd_nm,
		Coalesce(prd_cost,0) prd_cost,
		CASE UPPER(TRIM(prd_line))
			WHEN 'M' THEN 'Mountain' ------ We only use this short form of case statement when it is just mapping we are doing
			WHEN 'R' THEN 'Road'
			WHEN 'S' THEN 'Other Sales'
			WHEN 'T' THEN 'Touring'
		ELSE 'n/a'
		END prd_line,
		CAST(prd_start_dt AS DATE) prd_start_dt,
		CAST(LEAD(prd_start_dt) OVER(PARTITION BY prd_key ORDER BY prd_start_dt)-1 AS DATE) prd_end_dt---- this is to derive an end date of the record from the start date of the next record
	From Bronze.crm_prd_info;

	 SET @End_Time = GETDATE();
		PRINT'>> load Duration:' + CAST(DATEDIFF(second,@Start_Time,@End_Time) AS NVARCHAR) + ' seconds'
		PRINT'>> --------------------------------------------------------------------------------------------'

	/*cleaning and Loading the sales table*/
	SET @Start_Time = GETDATE ();
		PRINT'>>>Truncating Table: Silver.crm_sales_details'

	TRUNCATE TABLE Silver.crm_sales_details;
	PRINT'>> Inserting Data Into Silver.crm_sales_details '
	INSERT INTO Silver.crm_sales_details (
	sls_ord_num,
	sls_prd_key,
	sls_cust_id,
	sls_order_dt,
	sls_ship_dt,
	sls_due_dt,
	sls_sales,
	sls_quantity,
	sls_price
	)
	Select
		sls_ord_num,
		sls_prd_key,
		sls_cust_id,
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
		sls_quantity, 
		CASE WHEN sls_price <=0 or sls_price IS NULL 
			THEN sls_sales/NULLIF(sls_quantity,0)
			ELSE sls_price
			END sls_price
	From Bronze.crm_sales_details
	SET @End_Time = GETDATE();
		PRINT'>> load Duration:' + CAST(DATEDIFF(second,@Start_Time,@End_Time) AS NVARCHAR) + ' seconds'
		PRINT'>> ------------------------------------------------------------------------------------------'

	/* Cleaning and loading the erp Cust table*/
	SET @Start_Time = GETDATE ();
		PRINT'>>>Truncating Table: Silver.erp_CUST_AZ12'
	TRUNCATE TABLE Silver.erp_CUST_AZ12;
	PRINT'>> Inserting Data Into Silver.erp_CUST_AZ12'
	INSERT INTO Silver.erp_CUST_AZ12 (
	CID,
	BDATE,
	GEN
	)
	Select
		Case 
			When CID LIKE 'NAS%' 
			THEN SUBSTRING(CID,4,LEN(CID)) 
			ELSE CID  
		END CID,
		CASE 
			WHEN BDATE > GETDATE() 
			THEN NULL 
			ELSE BDATE 
		END BDATE,------ WE ARE ONLY REMOVING THE ONE WE ARE SURE OF SINCE BIRTHDAY CANNOT BE GREATER THAN PRESENT DATE 
		CASE UPPER(TRIM(GEN))
				WHEN 'F' THEN 'Female' ------ We only use this short form of case statement when it is just mapping we are doing
				WHEN 'M' THEN 'Male'
			ELSE 'n/a'
			END GEN
	From Bronze.erp_CUST_AZ12
	SET @End_Time = GETDATE();
		PRINT'>> load Duration:' + CAST(DATEDIFF(second,@Start_Time,@End_Time) AS NVARCHAR) + ' seconds'
		PRINT'>> ------------------------------------------------------------------------------------------'

	/* Cleaning and loading the LOC Erp table*/
	SET @Start_Time = GETDATE ();
		PRINT'>>>Truncating Table: Silver.erp_CUST_AZ12'
	TRUNCATE TABLE Silver.erp_LOC_A101;
	PRINT'>> Inserting Data Into Silver.erp_LOC_A101'

	INSERT INTO Silver.erp_LOC_A101 (
	CID,
	CNTRY
	)
	Select 
		REPLACE(CID,'-','') CID,
		CASE 
			WHEN UPPER(TRIM(CNTRY)) = 'DE' THEN 'Germany'
			WHEN UPPER(TRIM(CNTRY)) IN ('US','USA') THEN 'United States'
			WHEN UPPER(TRIM(CNTRY)) = '' Or CNTRY IS NULL THEN 'n/a'
			ELSE CNTRY
			END CNTRY
	From Bronze.erp_LOC_A101
	SET @End_Time = GETDATE();
	PRINT'>> load Duration:' + CAST(DATEDIFF(second,@Start_Time,@End_Time) AS NVARCHAR) + ' seconds'
	PRINT'>> ---------------------------------------------------------------------------------------------'

	/* Cleaning and loading the CAT Erp table*/
	SET @Start_Time = GETDATE ();
	PRINT'>>>Truncating Table: Silver.erp_PX_CAT_G1V2'
	TRUNCATE TABLE Silver.erp_PX_CAT_G1V2;
	PRINT'>> Inserting Data Into Silver.erp_PX_CAT_G1V2'
	INSERT INTO Silver.erp_PX_CAT_G1V2 (
	ID,
	CAT,
	SUBCAT,
	MAINTENANCE
	)
	Select 
	ID,
	CAT,
	SUBCAT,
	MAINTENANCE
	From Bronze.erp_PX_CAT_G1V2
	SET @End_Time = GETDATE();
	PRINT'>> load Duration:' + CAST(DATEDIFF(second,@Start_Time,@End_Time) AS NVARCHAR) + ' seconds'
	PRINT'>> ------------------------------------------------------------------------------------------------------'
	 SET @Batch_End_Time = GETDATE();
    PRINT'========================================================================================================='
    PRINT' ------ Batch loading completed--------------------------------------------------------------------------'
    PRINT'>> Batch load Duration:' + CASt(DATEDIFF(second,@Batch_Start_Time,@Batch_End_Time) AS NVARCHAR) + ' seconds'
    END TRY
    BEGIN CATCH
    PRINT'=========================================================================================================='
    PRINT'Error occured during loading Silver'
    PRINT'Error Message' + CAST(Error_Number () AS NVARCHAR) ------------------ casting to convert interger to string
    PRINT'=========================================================================================================='
    END CATCH
END

EXEC Silver.load_Silver;
