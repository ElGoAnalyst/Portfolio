/* 1. Find all customers whose order totals are greater than their
own average order total across the database. Use a correlated
subquery to determine each customer’s average order total.*/

SELECT ss.CustomerID
	, ss.SalesOrderID
	, ss.SubTotal
    , (
	SELECT AVG(s.SubTotal)
	FROM sales_salesorderheader AS s
	WHERE s.CustomerID = ss.CustomerID
       ) AS 'Average Order Total'
FROM sales_salesorderheader AS ss
WHERE ss.SubTotal > (
		    SELECT AVG(a.SubTotal)
                    FROM sales_salesorderheader AS a
                    WHERE a.CustomerID = ss.CustomerID
		    )
GROUP BY ss.CustomerID
	, ss.SalesOrderID;


/*2. Create a table with each product's average selling price and the
number of sales. Use this table to identify products whose number of
sales is greater than the average number of sales across all products.*/
 
WITH AVG_Price AS (
		SELECT ProductID
			, ROUND(AVG(UnitPrice), 2) AS 'Average Selling Price'
			, COUNT(*) AS 'Sales Count'
		FROM sales_salesorderdetail
		GROUP BY ProductID
                  ) 
SELECT ap.*
FROM AVG_Price AS ap 
WHERE ap.`Sales Count` > (
			SELECT AVG(apr.`Sales Count`) AS 'Average Sales Count'
                        FROM AVG_Price AS apr
                         );

/*3. Identify all products that have had at least one order exceeding
1000 units. Use EXISTS with a subquery to check for orders that meet
this criterion.*/

SELECT sa.ProductID
	, sa.SalesOrderID
 	, sa.OrderQty
FROM sales_salesorderdetail AS sa
WHERE EXISTS (
		SELECT ss.ProductID
			, ss.OrderQty
		FROM sales_salesorderdetail AS ss
		WHERE ss.ProductID = sa.ProductID
	     )
AND sa.OrderQty > 1000;


/*4. For each sales order, select the order ID and the total quantity
of items ordered. Additonally, include a column that shows the
highest quantity of a single item in that order, using a subquery in the
SELECT clause.*/

SELECT SalesOrderID
	, SUM(OrderQty) AS TotalQuantityOrdered
    , (
	SELECT MAX(OrderQty)
	FROM sales_salesorderdetail AS ss
	WHERE ss.SalesOrderID = sa.SalesOrderID
      ) AS HighestQty
FROM sales_salesorderdetail AS sa
GROUP BY SalesOrderID
ORDER BY TotalQuantityOrdered DESC;


/*5. Find all sales representatives who have sold products that are
no longer available. Use a subquery with NOT IN to list the sales
representatives whose sales include products that are not listed in
the current inventory.*/

SELECT DISTINCT(ss.SalesPersonID)
FROM sales_salesorderheader AS ss
JOIN sales_salesorderdetail AS sa ON sa.SalesOrderID = ss.SalesOrderID
WHERE sa.ProductID NOT IN (
			SELECT p.ProductID
                        FROM production_productinventory AS p
			  );


/*6. Identify customers who have not placed any orders in the last
year. Use a subquery with NOT IN to ﬁnd customers whose IDs do not
appear in the orders from the past year.*/


SELECT DISTINCT(s.CustomerID)
FROM sales_salesorderheader AS s
WHERE s.CustomerID NOT IN (
			SELECT ss.CustomerID
			FROM sales_salesorderheader AS ss
			WHERE ss.OrderDate BETWEEN '2013-01-01' AND '2014-01-01'
			  );
                         

/*7. Calculate the total sales for each year and compare each years
total sales with the overall average sales. Use a subquery to calculate
the overall average and then compare each years total against it.*/


SELECT YEAR(OrderDate)
	, SUM(SubTotal) AS Total_Sales
    , (
	SELECT AVG(a.SubTotal)
	FROM sales_salesorderheader AS a
      ) AS Average_Sales
FROM sales_salesorderheader AS b
GROUP BY YEAR(OrderDate)
ORDER BY 1 DESC;
