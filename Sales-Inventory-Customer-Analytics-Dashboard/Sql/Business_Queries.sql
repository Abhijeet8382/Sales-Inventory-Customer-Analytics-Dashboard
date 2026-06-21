SELECT  *
FROM FactInternetSales

SELECT  *
FROM DimCustomer

SELECT  *
FROM DimProduct

SELECT  *
FROM DimSalesTeritory


/* =========================================================
   Regional Profitability Analysis
   Purpose:
   Analyze revenue, profit, and profit margin across sales territories.
   Used in:
   Sales & Profitability Dashboard
========================================================= */

select b.SalesTerritoryRegion,
       sum(a.SalesAmount) as revenue,
       sum((a.SalesAmount-a.TotalProductCost)) as Profit,
       sum(a.SalesAmount-a.TotalProductCost)*100/sum(a.SalesAmount) as profit_margin
from FactInternetSales a
join DimSalesTerritory b
    on a.SalesTerritoryKey=b.SalesTerritoryKey
group by b.SalesTerritoryRegion
order by revenue desc, Profit desc, profit_margin desc;




/* =========================================================
   Customer Profit Decline Analysis
   Purpose:
   Identify customers whose yearly profit contribution
   declined by more than 30% compared to the previous year.
   Used in:
   Customer Insights & Retention Analysis Dashboard
========================================================= */

WITH cte1 AS
(
    SELECT
        b.CustomerKey,
        CONCAT(b.FirstName,' ',b.LastName) AS CustomerName,
        YEAR(a.OrderDate) AS Y,
        SUM(a.SalesAmount - a.TotalProductCost) AS Profit
    FROM FactInternetSales a
    JOIN DimCustomer b
        ON a.CustomerKey = b.CustomerKey
    GROUP BY
        b.CustomerKey,
        CONCAT(b.FirstName,' ',b.LastName),
        YEAR(a.OrderDate)
),
cte2 AS
(
    SELECT *,
           LAG(Profit) OVER
           (
               PARTITION BY CustomerKey
               ORDER BY Y
           ) AS PreviousYearProfit
    FROM cte1
)

SELECT
    CustomerKey,
    CustomerName,
    Y,
    Profit,
    PreviousYearProfit,
    ROUND(
        (Profit - PreviousYearProfit) * 100.0
        / PreviousYearProfit
    ,2) AS Profit_Change,
    (PreviousYearProfit-Profit) as Profit_Lost,
    CASE
        WHEN (Profit - PreviousYearProfit) * 100.0
             / PreviousYearProfit <= -30
        THEN 1
        ELSE 0
    END AS Decline_Flag
FROM cte2
WHERE PreviousYearProfit IS NOT NULL
  AND (Profit - PreviousYearProfit) * 100.0
      / PreviousYearProfit <= -30
ORDER BY Profit_Lost DESC;




/* =========================================================
   Product Revenue Contribution Analysis
   Purpose:
   Calculate each product's contribution percentage
   to total company revenue.
   Used for:
   Product Performance Evaluation
========================================================= */

select b.ProductKey,
       sum(a.SalesAmount)*100/
       (select sum(SalesAmount) from FactInternetSales) as Contribution
from FactInternetSales a
join DimProduct b
    on a.ProductKey=b.ProductKey
group by b.ProductKey
order by Contribution desc;




/* =========================================================
   High Profit / Low Sales Volume Products
   Purpose:
   Identify products generating above-average profit
   despite having below-average sales quantity.
   Used for:
   Hidden Opportunity Product Analysis
========================================================= */

with cte as
(
    select EnglishProductName,
           count(*) as quantity,
           sum(SalesAmount-TotalProductCost) as Profit
    from FactInternetSales a
    join DimProduct b
        on a.ProductKey=b.ProductKey
    group by EnglishProductName
)

select EnglishProductName,
       quantity,
       Profit,
       round((Profit * 1.0 / Quantity),2) AS Profit_Per_Unit
from cte
where quantity < (select avg(quantity) from cte)
and Profit > (select avg(profit) from cte)
order by Profit desc;




/* =========================================================
   Inventory Efficiency Analysis
   Purpose:
   Identify products with high safety stock levels
   but below-average profitability.
   Used in:
   Low-Performing Inventory Analysis Dashboard
========================================================= */

with cte as
(
    select EnglishProductName,
           SafetyStockLevel,
           sum(SalesAmount-TotalProductCost) as Profit
    from FactInternetSales a
    join DimProduct b
        on a.ProductKey=b.ProductKey
    group by EnglishProductName,
             SafetyStockLevel
)

select EnglishProductName,
       Profit,
       SafetyStockLevel,
       (Profit / SafetyStockLevel) as Inventory_Efficiency
from cte
where Profit < (select avg(profit) from cte)
and SafetyStockLevel > (select avg(SafetyStockLevel) from cte)
order by Inventory_Efficiency;



/* =========================================================
   View Creation: Customer Profit Decline
   Purpose:
   Create a reusable SQL view containing customers
   whose profit declined by more than 30% year-over-year.
   Used in:
   Power BI Customer Insights Dashboard
========================================================= */


CREATE VIEW vw_CustomerProfitDecline AS

WITH cte1 AS
(
    SELECT
        b.CustomerKey,
        CONCAT(b.FirstName,' ',b.LastName) AS CustomerName,
        YEAR(a.OrderDate) AS Y,
        SUM(a.SalesAmount - a.TotalProductCost) AS Profit
    FROM FactInternetSales a
    JOIN DimCustomer b
        ON a.CustomerKey = b.CustomerKey
    GROUP BY
        b.CustomerKey,
        CONCAT(b.FirstName,' ',b.LastName),
        YEAR(a.OrderDate)
),
cte2 AS
(
    SELECT *,
           LAG(Profit) OVER
           (
               PARTITION BY CustomerKey
               ORDER BY Y
           ) AS PreviousYearProfit
    FROM cte1
)

SELECT
    CustomerKey,
    CustomerName,
    Y,
    Profit,
    PreviousYearProfit,
    ROUND(
        (Profit - PreviousYearProfit) * 100.0
        / PreviousYearProfit
    ,2) AS Profit_Change,
    (PreviousYearProfit-Profit) AS Profit_Lost,
    CASE
        WHEN (Profit - PreviousYearProfit) * 100.0
             / PreviousYearProfit <= -30
        THEN 1
        ELSE 0
    END AS Decline_Flag
FROM cte2
WHERE PreviousYearProfit IS NOT NULL
  AND (Profit - PreviousYearProfit) * 100.0
      / PreviousYearProfit <= -30;