USE fifa_project;

select count(*) 
from players_21 
limit 10;

desc players_21;

select count(age )
from players_21;

-- age of the players 
select  min(age) as age_min, max(age) as age_max
from players_21;

-- average age players
select avg(age) as avg_age
from players_21;

select count( nationality) as number_of_nationnality
from players_21 ;

-- liste des nationnalites differentes 
select distinct nationality 
from players_21;

-- nombres de championnat differents
select count(distinct(league_name)) as nb_league
from players_21;

select nationality, count(nationality) as nationality 
from players_21 
group by nationality 
order by nationality desc 
limit 10;
-- number players of the club
select club_name, count(*) as number_of_players
from players_21
group by club_name 
order by  number_of_players desc
limit 10;

select count(*) as missing_club_names
from players_21
where club_name is null;

select * 
from players_21;
-- numbers_of_players per league
select league_name,  count(*) as number_of_players
from players_21 
group by  league_name 
order by number_of_players desc 
limit 10 ;

--  les 10 clubs ayant le plus grands note moyenne ... 
SELECT 
    club_name,
    AVG(overall) AS average_overall,
    COUNT(*) AS number_of_players
FROM players_21
GROUP BY club_name
HAVING COUNT(*) >= 20
ORDER BY average_overall DESC
LIMIT 10;
-- Ten of best players in value 
select short_name, age, club_name, value_eur
from players_21
order by value_eur desc
limit 10;

-- the 10 richest club
select club_name, sum(value_eur) as total_market_value
from players_21
group by club_name
order by somm_of_club_players desc
limit 10;

-- the biggest nationality of values 
select nationality,avg(value_eur) as average_value_of_nationality , count(*) numbers_of_players
from players_21
group by nationality
having count(*) >= 100
ORDER BY average_value_of_nationality DESC
limit 10;

select  club_name, avg(wage_eur) as higth_salary_avg,count(*) number_of_players
from players_21
group by club_name
having count(*) >= 25 
order by higth_salary_avg desc
limit 10;

SELECT
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(short_name) AS missing_short_name,
    COUNT(*) - COUNT(age) AS missing_age,
    COUNT(*) - COUNT(nationality) AS missing_nationality,
    COUNT(*) - COUNT(club_name) AS missing_club_name,
    COUNT(*) - COUNT(league_name) AS missing_league_name,
    COUNT(*) - COUNT(overall) AS missing_overall,
    COUNT(*) - COUNT(potential) AS missing_potential,
    COUNT(*) - COUNT(value_eur) AS missing_value_eur,
    COUNT(*) - COUNT(wage_eur) AS missing_wage_eur
FROM players_21;

-- 
select count(*) as players_without_club_and_league
from players_21 
where club_name is null and league_name is null ;

SELECT 
    short_name,
    age,
    nationality,
    overall,
    value_eur,
    club_name,
    league_name
FROM players_21
WHERE club_name IS NULL
  AND league_name IS NULL
ORDER BY overall DESC
LIMIT 20;

select count(*) as players_whithout_club_name_and_value_eur 
from players_21
where club_name is null and league_name is null and value_eur = 0;

-- Remplace values 
update players_21
set  
	club_name = 'free Agent',
    league_name = 'No league'
where club_name is null 
and league_name is null ;    


-- create copy table 
create table players_21_backup
select * 
from players_21;

SELECT COUNT(*) AS modified_rows
FROM players_21
WHERE club_name = 'Free Agent'
  AND league_name = 'No League';

UPDATE players_21_backup
SET 
    club_name = NULL,
    league_name = NULL
WHERE club_name = 'Free Agent'
  AND league_name = 'No League'
  AND value_eur = 0;

SELECT
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(club_name) AS missing_club_name,
    COUNT(*) - COUNT(league_name) AS missing_league_name
FROM players_21_backup;

use fifa_project;

-- check for duplicates players IDs 
select sofifa_id, count(*)
from players_21 
group by sofifa_id
having count(*) > 1;

-- Analyse the distribution of overall ratings(min, max, avg)
select min(overall) as minimum_overall, max(overall) as maximum_overall , avg(overall) as average_overall
from players_21;

-- Show all players whose overall rating is below 50
select 
	short_name, 
	overall
from players_21 
where overall < 50 
order by overall desc;

-- Show all players whose age is greater than 45 years old. 
select 
	short_name,
    age
from players_21
where age > 45
order by age desc ;

-- show players whose get value_eur 0 and overall more than or equal 75 
select short_name, value_eur, overall 
from players_21 
where value_eur = 0 and overall >= 75 
order by overall desc;

-- Top nationalities by average overall rating for players worth over €50 million
select nationality, 
avg(overall) as average_overall,
count(*) as number_of_players
from players_21 
where value_eur > 50000000 
group by nationality
order by average_overall desc; 

-- Find the players with unsually high wages 
select  
	short_name,
	club_name,
	wage_eur,
	overall
from players_21 
where wage_eur > 300000 
order by wage_eur desc;

-- analyze the distribution of players 
select 
	min(height_cm) as minimal_height,
	max(height_cm) as maximal_heigth,
	min(weight_kg) as minimal_weigth,
	max(weight_kg) as maximal_weigth,
    min(age) as minimal_age,
	max(age) as maximal_age
from players_21;

    





select *
from players_21
















