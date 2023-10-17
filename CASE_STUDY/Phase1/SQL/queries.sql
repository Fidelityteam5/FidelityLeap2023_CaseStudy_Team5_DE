/* ALL TABLES
customers(customer_ID, Street, City, State, Zip, Country, Age, Marital_Status, Gender, Number_Of_Dependents)
customer_assets2(Customer_ID, Asset_Objective_ID, Total)
Asset_Objectives(Asset_Objective_ID, Asset_Objective_Name)
Questions(question_id, QUESTION_SUBJECT,, QUESTION_TEXT)
customer_answers(Customer_ID, Question_ID, Answer_ID)
answers(QUESTION_ID, Answer_ID, ANSWER_TEXT, Risk_Profile_ID)
asset_classes(asset_class_id    ASSET_CLASS, RISK_PROFILE_ID)
RISK_PROFILE(RISK_PROFILE_id, RISK_PROFILE)
Fee_structures(Asset_Class_ID, Flat_Fee, Percentage_Fee)
potential_fund(Fund_id, Fund_Name, Fund_Description, Minimum_Investment_Required, Maximum_Investment_Allowed)
fund_assets(Fund_ID, Asset_Class_ID, Percent_Of_Fund)
customer_funds(Customer_ID, Fund_ID, Amount_Invested)
fund_targets(Fund_ID, Asset_Objective_ID, Engagement_Type_ID, Frequency_ID, Target_Description)
enagagement_frequencies(Frequency_id, Frequency_Name)
Engagement_Types(Engagement_Type_id, Engagement_Type_Name)
customer_engagement_frequencies(Customer_ID, Engagement_Type_ID, Frequency_ID)
*/

-- SCENARIO 1 
-- AGE, GENDER DISTRIBUTION 
select age, count(*) from customers group by age; 
select gender, count(*) from customers group by gender; 
select gender, age, count(*) from customers group by gender, age; 

-- REGIONAL DISTRIBUTION 
select city, count(*) from customers group by city; 
select state, count(*) from customers group by state; 
select zip, count(*) from customers group by zip; 
select country, count(*) from customers group by country; 
select city, state, count(*) from customers group by city, state; 
 
-- MARITAL_STATUS 
select Marital_Status, count(*) from customers group by Marital_Status; 

-- Is there relationship between customer’s available assets and number of dependents?  
-- Do not include individuals who have dependents but available assets of less than $100,000  
select c.customer_id, a.Asset_Objective_ID, c.number_of_dependents, a.total, c.number_of_dependents, avg(a.total) 
from customers c join customer_assets2 a 
on c.customer_id = a.customer_id 
where c.customer_id not in 
    (
        select c.customer_id  
        from customers c join customer_assets2 a 
        on c.customer_id = a.customer_id 
        where c.number_of_dependents >0 and a.total < 100000 
    ) 
group by c.number_of_dependents 
order by c.number_of_dependents; 

select c.number_of_dependents, ca.asset_objective_id, count(ca.asset_objective_id) as asset_count, sum(ca.total) as total_networth  
from customer c  join customer_assets ca on c.customer_id = ca.customer_id group by c.number_of_dependents , ca.asset_objective_id; 

create or replace view dependent_asset_relationship as   
select c.number_of_dependents, ca.asset_objective_id, count(ca.asset_objective_id) as asset_count, sum(ca.total) as total_networth  
from customer c join customer_assets ca on c.customer_id = ca.customer_id   
group by c.number_of_dependents , ca.asset_objective_id  
having sum(ca.total) > 100000 and c.number_of_dependents > 0 ; 

-- What is the range of assets available across various segments?  
-- What are the average available assets?  
-- What are the customer’s maximum investable assets available in each segment?  
create or replace view asset_segment as   
select cs.asset_objective_id , count(c.customer_id) as count_customers ,  
MIN(cs.Total) AS min_assets, MAX(cs.Total) AS max_assets, (max(cs.total) - min(cs.total)) as range_of_assets,  
AVG(cs.Total) AS avg_assets  
FROM customer c join customer_assets cs on c.customer_id = cs.customer_id GROUP BY asset_objective_id;  
Select * from asset_segemnt; 

-- SCENARIO 2 
-- Scenario 2: Viewing customer segments based on risk tolerance category 
-- What is the relationship between risk category and age? 
select rp.Risk_Profile_ID, rp.Risk_Profile, avg(c.age) 
from customers c 
join customer_assets2 ca on c.customer_ID = ca.customer_ID 
join customer_answers qa on c.customer_ID = qa.customer_ID 
join answers ans on qa.question_id = ans.question_id and qa.answer_id = ans.question_id 
join risk_profile rp on ans.Risk_Profile_ID = rp.Risk_Profile_ID 
group by rp.Risk_Profile_ID, rp.Risk_Profile 
order by rp.Risk_Profile_ID, rp.Risk_Profile; 

-- What is the relationship between available assets and risk category? 
select rp.Risk_Profile_ID, rp.Risk_Profile, avg(ca.total) 
from customer_assets2 ca 
join customer_answers qa on ca.customer_ID = qa.customer_ID 
join answers ans on qa.question_id = ans.question_id and qa.answer_id = ans.question_id 
join risk_profile rp on ans.Risk_Profile_ID = rp.Risk_Profile_ID 
group by rp.Risk_Profile_ID, rp.Risk_Profile 
order by rp.Risk_Profile_ID, rp.Risk_Profile; 

-- Are there regional variations in the distribution of risk category?  
select rp.Risk_Profile_ID, rp.Risk_Profile, c.state -- c.zip, c.city 
from customers c 
join customer_assets2 ca on c.customer_ID = ca.customer_ID 
join customer_answers qa on c.customer_ID = qa.customer_ID 
join answers ans on qa.question_id = ans.question_id and qa.answer_id = ans.question_id 
join risk_profile rp on ans.Risk_Profile_ID = rp.Risk_Profile_ID 
order by rp.Risk_Profile, c.state; 

-- Scenario 3: Determining potential revenue for the mix of asset classes for the created funds 
-- Once a mix of asset classes (the fund) is chosen, what is the risk category it would be assigned?  


-- For created funds calculate the approximate minimum and maximum revenue per customer  
-- (hint: multiply the fee structure by minimum investment required and maximum allowed by an individual)  

CREATE or replace VIEW customer_fund_revenue AS 
  SELECT p.Fund_name, p.Fund_Id,  
    SUM(p.Minimum_Investment_Required*f.Percent_Of_Fund*fs.percentage_fee) AS min_customer_revenue, 
    SUM(p.Maximum_Investment_Allowed*f.Percent_Of_Fund*fs.percentage_fee) AS max_customer_revenue 
  FROM fund_assets f  
  JOIN potential_funds p ON p.Fund_Id = f.Fund_ID 
  JOIN fee_structure fs ON f.Asset_Class_ID = fs.asset_class_id 
  GROUP BY p.Fund_name, p.Fund_Id 
  ORDER BY min_customer_revenue DESC; 

-- What is the potential revenue by customer segment?  
-- (hint: multiply number of customers in segment by minimum and maximum revenue) 

-- population
CREATE or replace VIEW potential_revenue AS
SELECT Fund_name, Fund_Id, min_customer_revenue*population, max_customer_revenue*population
from customer_fund_revenue
GROUP BY p.Fund_name, p.Fund_Id;


-- Creating Tables
CREATE TABLE asset_details 
(
    asset_class_id	INT,
    asset_class	VARCHAR(512),
    risk_profile_id	INT,
    avg_10_year_return	DOUBLE PRECISION,
    stddev_10_year	DOUBLE PRECISION,
    flat_fee	VARCHAR(512),
    percentage_fee	DOUBLE PRECISION
);

INSERT INTO asset_details (asset_class_id, asset_class, risk_profile_id, avg_10_year_return, stddev_10_year, flat_fee, percentage_fee) VALUES ('1', 'Bonds', '1', '4.44', '3.29', '0', '0.005');
INSERT INTO asset_details (asset_class_id, asset_class, risk_profile_id, avg_10_year_return, stddev_10_year, flat_fee, percentage_fee) VALUES ('2', 'Large Cap', '3', '7.85', '14.32', '0', '0.003');
INSERT INTO asset_details (asset_class_id, asset_class, risk_profile_id, avg_10_year_return, stddev_10_year, flat_fee, percentage_fee) VALUES ('3', 'US Mid Cap', '3', '9.55', '17.68', '0', '0.004');
INSERT INTO asset_details (asset_class_id, asset_class, risk_profile_id, avg_10_year_return, stddev_10_year, flat_fee, percentage_fee) VALUES ('4', 'US Small Cap', '4', '9.22', '19.55', '0', '0.008');
INSERT INTO asset_details (asset_class_id, asset_class, risk_profile_id, avg_10_year_return, stddev_10_year, flat_fee, percentage_fee) VALUES ('5', 'Foreign Ex', '4', '2.26', '18.21', '0', '0.01');
INSERT INTO asset_details (asset_class_id, asset_class, risk_profile_id, avg_10_year_return, stddev_10_year, flat_fee, percentage_fee) VALUES ('6', 'Emerging', '5', '5.57', '23.6', '0', '0.02');
INSERT INTO asset_details (asset_class_id, asset_class, risk_profile_id, avg_10_year_return, stddev_10_year, flat_fee, percentage_fee) VALUES ('7', 'Commodities', '5', '-2.62', '18.11', '0', '0.05');
INSERT INTO asset_details (asset_class_id, asset_class, risk_profile_id, avg_10_year_return, stddev_10_year, flat_fee, percentage_fee) VALUES ('8', 'Market ETF', '2', '5.78', '7.25', '0', '0.004');

CREATE TABLE fund_details 
(
    fund_id	VARCHAR(512),
    fund_name	VARCHAR(512),
    bond_pct	DOUBLE PRECISION,
    lc_pct	DOUBLE PRECISION,
    mid_pct	DOUBLE PRECISION,
    small_pct	DOUBLE PRECISION,
    fgn_pct	DOUBLE PRECISION,
    emerg_pct	DOUBLE PRECISION,
    comm_pct	DOUBLE PRECISION,
    metf_pct	DOUBLE PRECISION,
    risk_score	DOUBLE PRECISION,
    avg_returns	DOUBLE PRECISION
);

INSERT INTO fund_details (fund_id, fund_name, bond_pct, lc_pct, mid_pct, small_pct, fgn_pct, emerg_pct, comm_pct, metf_pct, risk_score, avg_returns) VALUES ('1', 'Retirement Segment', '29', '0', '16', '18', '16', '12', '10', '0', '2.89', '5.22');
INSERT INTO fund_details (fund_id, fund_name, bond_pct, lc_pct, mid_pct, small_pct, fgn_pct, emerg_pct, comm_pct, metf_pct, risk_score, avg_returns) VALUES ('2', 'Gold and Peace Segment', '32', '7', '22', '20', '11', '8', '0', '0', '2.48', '6.60');
INSERT INTO fund_details (fund_id, fund_name, bond_pct, lc_pct, mid_pct, small_pct, fgn_pct, emerg_pct, comm_pct, metf_pct, risk_score, avg_returns) VALUES ('3', 'Early Bird Segment', '10', '0', '0', '20', '35', '15', '20', '0', '3.7', '3.39');
INSERT INTO fund_details (fund_id, fund_name, bond_pct, lc_pct, mid_pct, small_pct, fgn_pct, emerg_pct, comm_pct, metf_pct, risk_score, avg_returns) VALUES ('4', 'Premium Wealth Maximizer', '27', '0', '0', '24', '21', '18', '0', '10', '3.05', '5.46');
INSERT INTO fund_details (fund_id, fund_name, bond_pct, lc_pct, mid_pct, small_pct, fgn_pct, emerg_pct, comm_pct, metf_pct, risk_score, avg_returns) VALUES ('5.1', 'WWOF_low_risk', '49', '12', '11', '7', '0', '7', '0', '14', '2.09', '6.01');
INSERT INTO fund_details (fund_id, fund_name, bond_pct, lc_pct, mid_pct, small_pct, fgn_pct, emerg_pct, comm_pct, metf_pct, risk_score, avg_returns) VALUES ('5.2', 'WWOF_mid_risk', '27', '16', '16', '16', '0', '10', '0', '15', '2.67', '6.88');
INSERT INTO fund_details (fund_id, fund_name, bond_pct, lc_pct, mid_pct, small_pct, fgn_pct, emerg_pct, comm_pct, metf_pct, risk_score, avg_returns) VALUES ('5.3', 'WWOF_high_risk', '15', '15', '18', '28', '0', '15', '0', '9', '3.19', '7.49');




--------------------------------------------------------------------------------------------------------------

-- PL/SQL

-- Create functions for each of the calculations used in the views in the previous activity. 
-- in scenario 3
-- At minimum include functions for the following: 

-- Assigning customers to a risk tolerance category by using a rounded average of the customer’s answers to the 
-- 8 questions in the risk questionnaire data (the risk questionnaire questions can be found in Appendix E)
CREATE OR REPLACE FUNCTION get_risk_profile_customers
RETURN SYS_REFCURSOR
IS
  result_cursor SYS_REFCURSOR;
BEGIN
  OPEN result_cursor FOR
    SELECT rp.Risk_Profile_ID, rp.Risk_Profile, c.customer_ID 
    FROM customers c 
    JOIN customer_assets2 ca ON c.customer_ID = ca.customer_ID 
    JOIN customer_answers qa ON c.customer_ID = qa.customer_ID 
    JOIN answers ans ON qa.question_id = ans.question_id AND qa.answer_id = ans.question_id 
    JOIN risk_profile rp ON ans.Risk_Profile_ID = rp.Risk_Profile_ID 
    GROUP BY rp.Risk_Profile_ID, rp.Risk_Profile 
    ORDER BY rp.Risk_Profile_ID, rp.Risk_Profile;
  RETURN result_cursor;
END;

-- Calculating the minimum and maximum potential revenue per customer for the potential fund view(s) 
CREATE OR REPLACE FUNCTION get_potential_revenue
RETURN SYS_REFCURSOR
IS
  result_cursor SYS_REFCURSOR;
BEGIN
  OPEN result_cursor FOR
    WITH customer_fund_revenue AS (
      SELECT p.Fund_name, p.Fund_Id,  
        SUM(p.Minimum_Investment_Required*f.Percent_Of_Fund*fs.percentage_fee) AS min_customer_revenue, 
        SUM(p.Maximum_Investment_Allowed*f.Percent_Of_Fund*fs.percentage_fee) AS max_customer_revenue 
      FROM fund_assets f  
      JOIN potential_funds p ON p.Fund_Id = f.Fund_ID 
      JOIN fee_structure fs ON f.Asset_Class_ID = fs.asset_class_id 
      GROUP BY p.Fund_name, p.Fund_Id 
    )
    SELECT Fund_name, Fund_Id, min_customer_revenue*population AS min_potential_revenue, max_customer_revenue*population AS max_potential_revenue
    FROM customer_fund_revenue
    GROUP BY Fund_name, Fund_Id;
  RETURN result_cursor;
END;


-- Calculating the weighted average risk score of your fund samples

