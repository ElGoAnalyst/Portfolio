-- Use ROW_NUMBER() to assign a unique sequential integer to rows within a partition of a result set, ordered by SalesAmount in descending order.

SELECT SalesOrderID
	, ROUND(LineTotal, 2) AS SalesAmount
    	, ROW_NUMBER() OVER(PARTITION BY SalesOrderID ORDER BY LineTotal DESC) AS 'Row Number'
FROM sales_salesorderdetail;

-- Utilize RANK() to rank the total sales of each salesperson within their respective region.

SELECT TerritoryID
	, SalesPersonID
    	, SUM(SubTotal) AS Total_Sales
    	, RANK() OVER(PARTITION BY TerritoryID ORDER BY SUM(SubTotal) DESC) AS 'Rank'
FROM sales_salesorderheader
GROUP BY TerritoryID
	, SalesPersonID
ORDER BY TerritoryID ASC;

-- Apply DENSE_RANK() to determine the ranking of products based on their inventory levels without gaps in the ranking values.

SELECT ProductID
	, Quantity
    	, DENSE_RANK() OVER( ORDER BY Quantity DESC) AS 'Rank'
FROM production_productinventory;

-- Use NTILE(4) to divide the customers into four quartiles based on their total purchase amount.

SELECT CustomerID
    	, SUM(SubTotal) AS TotalPurchaseAmount
    	, NTILE(4) OVER(ORDER BY SUM(SubTotal) DESC) AS GroupNumber
FROM sales_salesorderheader
GROUP BY CustomerID;

-- Employ LEAD() to compare the sales of each product with the sales of the next product (in terms of inventory sequence).

WITH InventorySequence AS (
			SELECT ProductID
				, ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) AS Sequence
			FROM production_productinventory
			GROUP BY ProductID
),
SalesSummary AS (
		SELECT DATE_FORMAT(ss.OrderDate, '%Y-%m') AS OrderDate
			, p.ProductID
			, p.Name
			, ROUND(SUM(s.LineTotal), 2) AS SalesAmount
		FROM production_product AS p
		JOIN sales_salesorderdetail AS s ON s.ProductID = p.ProductID
		JOIN sales_salesorderheader AS ss ON ss.SalesOrderID = s.SalesOrderID
		GROUP BY p.ProductID
			, p.Name
			, DATE_FORMAT(ss.OrderDate, '%Y-%m')
)
SELECT s.*
	, LEAD(s.SalesAmount) OVER(PARTITION BY s.OrderDate ORDER BY i.Sequence ASC) AS NextProductSales
FROM SalesSummary AS s
JOIN InventorySequence AS i ON i.ProductID = s.ProductID
ORDER BY s.OrderDate ASC;  

-- Utilize LAG() to compare the monthly sales of a product with the sales in the previous month.

WITH Monthly_Sales AS (
		SELECT DATE(ss.OrderDate) AS OrderDate
			, p.ProductID
			, p.Name
			, ROUND(SUM(s.LineTotal), 2) AS MonthlySales
		FROM production_product AS p
		JOIN sales_salesorderdetail AS s ON s.ProductID = p.ProductID
		JOIN sales_salesorderheader AS ss ON ss.SalesOrderID = s.SalesOrderID
		GROUP BY p.ProductID
			, p.Name
			, DATE(ss.OrderDate)
		ORDER BY p.ProductID ASC
			, OrderDate ASC
)
SELECT m.*
	, LAG(MonthlySales) OVER(PARTITION BY ProductID ORDER BY OrderDate) AS PreviousMonthSales
FROM Monthly_Sales AS m;


-- Implement FIRST_VALUE() to identify the first sale transaction made by each salesperson.

SELECT fv.SalesPersonID
	, MAX(fv.FirstSalesOrderID) AS FirstSalesOrderID
    	, MAX(fv.FirstOrderDate) AS FirstOrderDate
FROM (
	SELECT SalesPersonID
		, FIRST_VALUE(SalesOrderID) OVER(PARTITION BY SalesPersonID ORDER BY OrderDate ASC) AS FirstSalesOrderID
		, FIRST_VALUE(OrderDate) OVER(PARTITION BY SalesPersonID ORDER BY OrderDate ASC) AS FirstOrderDate
	FROM sales_salesorderheader
) AS fv
GROUP BY fv.SalesPersonID
ORDER BY fv.SalesPersonID ASC;


-- Use LAST_VALUE() to find the most recent purchase made by each customer, considering their entire purchase history.

SELECT c.CustomerID
    , c.RecentPurchase_ProductID
    , c.OrderDate
FROM (
	SELECT sh.CustomerID
		, LAST_VALUE(sa.ProductID) OVER(PARTITION BY sh.CustomerID ORDER BY sh.OrderDate ASC ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS RecentPurchase_ProductID
		, LAST_VALUE(sh.OrderDate) OVER(PARTITION BY sh.CustomerID ORDER BY sh.OrderDate ASC ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS OrderDate
    		, ROW_NUMBER() OVER(PARTITION BY sh.CustomerID ORDER BY (SELECT NULL)) AS RowNumber
	FROM sales_salesorderheader AS sh
	JOIN sales_salesorderdetail AS sa ON sa.SalesOrderID = sh.SalesOrderID
) AS c
WHERE c.RowNumber = 1;


-- Apply CUME_DIST() to calculate the cumulative distribution of sales amounts across all sales transactions.

SELECT SalesOrderID
    , ProductId
    , LineTotal AS SalesAmount
    , ROUND((CUME_DIST() OVER(ORDER BY LineTotal ASC) * 100), 3) AS SalesQuota
FROM sales_salesorderdetail;

-- Use PERCENT_RANK() to calculate the relative rank of each employee's sales within their department.

WITH Emp_Sales AS (
		SELECT d.DepartmentID 
			, d.Name
			, s.SalesPersonID
			, ROUND(SUM(s.SubTotal), 2) AS TotalSales
		FROM humanresources_department AS d
		JOIN humanresources_employeedepartmenthistory AS e ON e.DepartmentID = d.DepartmentID
		JOIN sales_salesorderheader AS s ON s.SalesPersonID = e.BusinessEntityID
		GROUP BY s.SalesPersonID
			, d.DepartmentID
			, d.Name
)
SELECT es.*
	, PERCENT_RANK() OVER(PARTITION BY es.DepartmentID ORDER BY es.TotalSales ASC) AS PercentRank
FROM Emp_Sales AS es;

-- Employ the windowed SUM() function to calculate the running total of sales for each product category over time.

WITH Cat_Sales AS (
		SELECT pc.ProductCategoryID
			, pc.Name
			, DATE(sh.OrderDate) AS OrderDate
			, SUM(s.LineTotal) AS TotalSales
		FROM sales_salesorderheader AS sh 
		JOIN sales_salesorderdetail AS s ON s.SalesOrderID = sh.SalesOrderID
		JOIN production_product AS pp ON pp.ProductID = s.ProductID
		JOIN production_productsubcategory AS ps ON ps.ProductSubCategoryID = pp.ProductSubCategoryID
		JOIN production_productcategory AS pc ON pc.ProductCategoryID = ps.ProductCategoryID
		GROUP BY pc.ProductCategoryID
			, pc.Name
			, DATE(sh.OrderDate)
)
SELECT cs.ProductCategoryID
	, cs.Name
    	, cs.OrderDate
    	, ROUND(SUM(cs.TotalSales) OVER(PARTITION BY CS.ProductCategoryID ORDER BY cs.OrderDate ASC), 2) AS Running_Total_Sales
FROM Cat_Sales AS cs
ORDER BY cs.ProductCategoryID ASC
    	, cs.OrderDate ASC;

-- Utilize the windowed AVG() function to calculate the moving average of daily sales over a 7-day period.

SELECT DATE(OrderDate) AS Order_Date
	, ROUND(AVG(SUM(SubTotal)) OVER(ORDER BY DATE(OrderDate) ASC ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 2) AS 7_Day_Moving_Average
FROM sales_salesorderheader
GROUP BY DATE(OrderDate)
ORDER BY Order_Date ASC;

-- Implement COUNT() as a window function to count the number of sales transactions for each salesperson.

SELECT SalesPersonID
	, COUNT(*) OVER(PARTITION BY SalesPersonID) AS Sales_Count
FROM sales_salesorderheader;

-- Use MAX() as a window function to identify the largest sale made by each salesperson.

SELECT SalesPersonID
	, SalesOrderID
    	, SubTotal
	, MAX(SubTotal) OVER(PARTITION BY SalesPersonID) AS Largest_Sale
FROM sales_salesorderheader
ORDER BY SalesPersonID DESC
	, Largest_Sale DESC;


-- Apply MIN() as a window function to find the smallest sale amount in each product category.

SELECT pc.ProductCategoryID
	, pc.Name
    	, sh.SalesOrderID
    	, sh.SubTotal
    	, MIN(sh.SubTotal) OVER(PARTITION BY pc.ProductCategoryID) AS Smallest_Sale_Amount
FROM sales_salesorderheader AS sh 
JOIN sales_salesorderdetail AS s ON s.SalesOrderID = sh.SalesOrderID
JOIN production_product AS pp ON pp.ProductID = s.ProductID
JOIN production_productsubcategory AS ps ON ps.ProductSubCategoryID = pp.ProductSubCategoryID
JOIN production_productcategory AS pc ON pc.ProductCategoryID = ps.ProductCategoryID
ORDER BY pc.ProductCategoryID ASC;

-- Use window functions to calculate the year-to-date (YTD) total sales for each salesperson.

SELECT SalesPersonID
	, DATE(OrderDate) AS Order_Date
    	, SubTotal
    	, SUM(SubTotal) OVER(PARTITION BY SalesPersonID, YEAR(OrderDate) ORDER BY DATE(OrderDate) ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS YTD
FROM sales_salesorderheader
ORDER BY SalesPersonID DESC
	, Order_Date ASC;

-- Utilize window functions to rank salespeople in each region based on their average quarterly sales.

WITH Quarter_Sales AS (
		SELECT s.TerritoryID
            		, t.Name 
            		, s.SalesPersonID
			, YEAR(s.OrderDate) AS Year
			, QUARTER(s.OrderDate) AS Quarter
			, ROUND(AVG(s.SubTotal), 2) AS AVG_Quarter_Sales
		FROM sales_salesorderheader AS s
		JOIN  sales_salesterritory AS t ON t.TerritoryID = s.TerritoryID
		GROUP BY s.SalesPersonID
			, s.TerritoryID
			, YEAR(s.OrderDate)
			, QUARTER(s.OrderDate)
)
SELECT s.*
	, RANK() OVER(PARTITION BY s.TerritoryID, Year, Quarter ORDER BY AVG_Quarter_Sales DESC) AS 'Rank'
FROM Quarter_Sales AS s
ORDER BY s.TerritoryID ASC;


-- Implement a window function to find the difference in sales amount between each sale and the average sale of the day.

WITH Sales AS (
	SELECT DATE(OrderDate) AS OrderDate
		, ROUND(AVG(SubTotal), 2) AS AverageSale
		, ROUND(SUM(SubTotal), 2) AS TotalSales
	FROM sales_salesorderheader
	GROUP BY DATE(OrderDate)
)
SELECT s.*
	, LAG(s.TotalSales) OVER(ORDER BY s.OrderDate ASC) AS PreviousDay
   	, ((ROUND((s.TotalSales - LAG(s.TotalSales) OVER(ORDER BY s.OrderDate ASC)) / LAG(s.TotalSales) OVER(ORDER BY s.OrderDate ASC), 2)) * 100) AS PercentChange
FROM Sales AS s
ORDER BY s.OrderDate ASC;

-- Use window functions to identify the top 3 best-selling products in each category.

WITH Category_Sales AS (
		SELECT pc.ProductCategoryID
			, pc.Name
			, s.ProductID
			, COUNT(*) AS Sales_Count
		FROM sales_salesorderdetail AS s
		JOIN production_product AS p ON p.ProductID = s.ProductID
		JOIN production_productsubcategory AS ps ON ps.ProductSubcategoryID = p.ProductSubcategoryID
		JOIN production_productcategory AS pc ON pc.ProductCategoryID = ps.ProductCategoryID
		GROUP BY pc.ProductCategoryID
			, pc.Name
			, s.ProductID
),
Best AS (
	SELECT cs.*
		, DENSE_RANK() OVER(PARTITION BY cs.ProductCategoryID ORDER BY cs.Sales_Count DESC) AS Best_Selling
	FROM Category_Sales AS cs
)
SELECT b.*
FROM Best AS b
WHERE b.Best_Selling BETWEEN 1 AND 3
ORDER BY b.ProductCategoryID ASC
	, b.Best_Selling ASC;


-- Apply a window function to calculate the percentage contribution of each product to the total sales of its category.

WITH Sales AS (
	SELECT pc.ProductCategoryID
		, pc.Name
		, s.ProductID
		, SUM(s.LineTotal) AS Sales_Per_Product
		, SUM(SUM(s.LineTotal)) OVER(PARTITION BY pc.ProductCategoryID) AS Total_Sales_Per_Category
	FROM sales_salesorderdetail AS s
	JOIN production_product AS p ON p.ProductID = s.ProductID
	JOIN production_productsubcategory AS ps ON ps.ProductSubcategoryID = p.ProductSubcategoryID
	JOIN production_productcategory AS pc ON pc.ProductCategoryID = ps.ProductCategoryID
	GROUP BY pc.ProductCategoryID
		, pc.Name
		, s.ProductID
)
SELECT s.ProductCategoryID
	, s.Name
	, s.ProductID
    	, ROUND(s.Sales_Per_Product, 2) AS Sales_Per_Product
    	, ROUND(s.Total_Sales_Per_Category, 2) AS Total_Sales_Per_Category
	, ROUND(((s.Sales_Per_Product / s.Total_Sales_Per_Category) * 100), 2) AS Percentage_Contribution
FROM Sales AS s
ORDER BY s.ProductCategoryID ASC
	, Percentage_Contribution DESC;


-- Employ window functions to compare the sales growth of each product month-over-month.

WITH Monthly_Sales AS (
		SELECT s.ProductID
			, YEAR(h.OrderDate) AS Year
			, MONTH(h.OrderDate) AS Month
			, SUM(s.LineTotal) AS TotalSales
		FROM sales_salesorderheader AS h
		JOIN sales_salesorderdetail AS s ON s.SalesOrderID = h.SalesOrderID
		GROUP BY s.ProductID
			, YEAR(h.OrderDate) 
			, MONTH(h.OrderDate)
		ORDER BY s.ProductID ASC
			, Year ASC
			, Month ASC
),
Previous AS (
	SELECT m.*
		, LAG(m.TotalSales) OVER(PARTITION BY m.ProductID ORDER BY m.Year ASC, m.Month ASC) AS PreviousMonth
	FROM Monthly_Sales AS m
)
SELECT p.ProductID
	, p.Year
    , p.Month
    , ROUND(p.TotalSales, 2) AS TotalSales
    , ROUND(p.PreviousMonth, 2) AS PreviousMonth
    , ROUND((((p.TotalSales / p.PreviousMonth) - 1) * 100), 2) AS SalesGrowth 
FROM Previous AS p
ORDER BY p.ProductID ASC
	, p.Year ASC
    	, p.Month ASC;


-- Utilize window functions to determine the median sales amount for each day.

WITH Sales AS (
	SELECT DATE(OrderDate) AS OrderDate
		, SubTotal
		, ROW_NUMBER() OVER(PARTITION BY DATE(OrderDate) ORDER BY SubTotal ASC) AS RowNumber
		, COUNT(*) OVER(PARTITION BY DATE(OrderDate)) AS RowCount
	FROM sales_salesorderheader
	ORDER BY OrderDate ASC
		, SubTotal ASC
),
Median AS (
	SELECT s.OrderDate
		, ROUND(s.SubTotal, 2) AS SalesAmount
		, s.RowNumber
		, CEIL(0.5 * s.RowCount) AS MedianPosition
	FROM Sales AS s
)
SELECT m.OrderDate
	, m.SalesAmount AS Median_Sales_Amount
FROM Median AS m
WHERE m.RowNumber = m.MedianPosition
ORDER BY OrderDate ASC;


-- Implement window functions to find the salesperson with the highest average sale amount in each region.

WITH Average_Sales AS (
	SELECT h.TerritoryID
		, t.Name AS TerritoryName
		, h.SalesPersonID
		, AVG(h.SubTotal) AS AverageSalesAmount
	FROM sales_salesorderheader AS h
	JOIN sales_salesterritory AS t ON t.TerritoryID = h.TerritoryID
	GROUP BY h.SalesPersonID
		, h.TerritoryID
		, t.Name 
	ORDER BY h.TerritoryID ASC
		, AverageSalesAmount DESC
)
SELECT a.TerritoryID
	, a.TerritoryName
    	, a.SalesPersonID
    	, ROUND(MAX(a.AverageSalesAmount) OVER(PARTITION BY a.TerritoryID), 2) AS HighestSaleAmount
FROM Average_Sales AS a
GROUP BY a.TerritoryID
	, a.TerritoryName
ORDER BY a.TerritoryID ASC;


-- Apply window functions to identify the month with the highest average sales for each year.

WITH Average_Sales AS (
		SELECT YEAR(OrderDate) AS Year
			, MONTH(OrderDate) AS Month
			, AVG(SubTotal) AS AverageSales
		FROM sales_salesorderheader
		GROUP BY YEAR(OrderDate)
			, MONTH(OrderDate)
),
Best AS (
	SELECT a.Year
		, MAX(a.AverageSales) OVER(PARTITION BY a.Year) AS Highest_Average_Sale
		, FIRST_VALUE(a.Month) OVER(PARTITION BY a.Year ORDER BY a.AverageSales DESC) AS Best_Month
	FROM Average_Sales AS a
)
SELECT b.Year
	, ROUND(b.Highest_Average_Sale, 2) AS Highest_Average_Sale
    	, b.Best_Month
FROM Best AS b
GROUP BY b.Year
ORDER BY b.Year ASC;
