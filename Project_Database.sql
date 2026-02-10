USE portfolio_db;

-- select * from vaccinations order by 3, 4;
select * from covid_deaths where continent is not null order by 3, 4;

-- clean up null and '' in dataset
UPDATE covid_deaths
SET 
-- Geographic & Identifiers
    iso_code = NULLIF(TRIM(iso_code), ''),
    continent = NULLIF(TRIM(continent), ''),
    location = NULLIF(TRIM(location), ''),
    
-- Date (Ensure this is cleaned before CASTING to DATE type)
    date = NULLIF(TRIM(date), ''),

-- Population & Integers
    population = NULLIF(TRIM(population), ''),
    total_cases = NULLIF(TRIM(total_cases), ''),
    new_cases = NULLIF(TRIM(new_cases), ''),
    new_cases_smoothed = nullif(TRIM(new_cases_smoothed), ''),
    total_deaths = NULLIF(TRIM(total_deaths), ''),
    new_deaths = NULLIF(TRIM(new_deaths), ''),
    new_deaths_smoothed = NULLIF(TRIM(new_deaths_smoothed), ''),
    icu_patients = NULLIF(TRIM(icu_patients), ''),
    hosp_patients = NULLIF(TRIM(hosp_patients), ''),
    weekly_icu_admissions = NULLIF(TRIM(weekly_icu_admissions), ''),
    weekly_hosp_admissions = NULLIF(TRIM(weekly_hosp_admissions), ''),

-- Rates & Decimals (Including Smoothed data)
    reproduction_rate = NULLIF(TRIM(reproduction_rate), ''),
    new_cases_smoothed = NULLIF(TRIM(new_cases_smoothed), ''),
    new_deaths_smoothed = NULLIF(TRIM(new_deaths_smoothed), ''),
    
-- Per Million Metrics
    total_cases_per_million = NULLIF(TRIM(total_cases_per_million), ''),
    new_cases_per_million = NULLIF(TRIM(new_cases_per_million), ''),
    new_cases_smoothed_per_million = NULLIF(TRIM(new_cases_smoothed_per_million), ''),
    total_deaths_per_million = NULLIF(TRIM(total_deaths_per_million), ''),
    new_deaths_per_million = NULLIF(TRIM(new_deaths_per_million), ''),
    new_deaths_smoothed_per_million = NULLIF(TRIM(new_deaths_smoothed_per_million), ''),
    icu_patients_per_million = NULLIF(TRIM(icu_patients_per_million), ''),
    hosp_patients_per_million = NULLIF(TRIM(hosp_patients_per_million), ''),
    weekly_icu_admissions_per_million = NULLIF(TRIM(weekly_icu_admissions_per_million), ''),
    weekly_hosp_admissions_per_million = NULLIF(TRIM(weekly_hosp_admissions_per_million), ''); 

-- modify table data type
ALTER TABLE covid_deaths

-- Geographic Identifiers
MODIFY COLUMN iso_code VARCHAR(13),
MODIFY COLUMN continent VARCHAR(50),
MODIFY COLUMN location VARCHAR(100),

-- Date and Time
MODIFY COLUMN date DATE,

-- Population and Raw Totals
MODIFY COLUMN population BIGINT,
MODIFY COLUMN total_cases BIGINT,
MODIFY COLUMN new_cases BIGINT,
MODIFY COLUMN total_deaths BIGINT,
MODIFY COLUMN new_deaths BIGINT,

-- Hospitalization Data
MODIFY COLUMN icu_patients BIGINT,
MODIFY COLUMN hosp_patients BIGINT,
MODIFY COLUMN weekly_icu_admissions DECIMAL(12, 3),
MODIFY COLUMN weekly_hosp_admissions DECIMAL(12, 3),

-- Rates and Smoothed Data (Decimals)
MODIFY COLUMN reproduction_rate DECIMAL(10, 2),
MODIFY COLUMN new_cases_smoothed DECIMAL(12, 3),
MODIFY COLUMN new_deaths_smoothed DECIMAL(12, 3),

-- Normalized Data (Per Million)
MODIFY COLUMN total_cases_per_million DECIMAL(15, 3),
MODIFY COLUMN new_cases_per_million DECIMAL(15, 3),
MODIFY COLUMN new_cases_smoothed_per_million DECIMAL(15, 3),
MODIFY COLUMN total_deaths_per_million DECIMAL(15, 3),
MODIFY COLUMN new_deaths_per_million DECIMAL(15, 3),
MODIFY COLUMN new_deaths_smoothed_per_million DECIMAL(15, 3),
MODIFY COLUMN icu_patients_per_million DECIMAL(15, 3),
MODIFY COLUMN hosp_patients_per_million DECIMAL(15, 3),
MODIFY COLUMN weekly_icu_admissions_per_million DECIMAL(15, 3),
MODIFY COLUMN weekly_hosp_admissions_per_million DECIMAL(15, 3);
 
-- Data Analysis Phase 
select location, date, population, total_cases, 
total_deaths * 100/total_cases as death_percent
from covid_deaths 
where location like '%states%' 
order by 1,2;

select location, date, population, total_cases, 
(total_cases * 100) / population  as infected_percent
from covid_deaths 
where location like '%states%' 
order by 1,2;

-- Looking at countries have highest infection rate compared to population 
select location, population, max(total_cases * 100/ population) as infected_rate, max(total_cases) as Highest_Infected_Count from covid_deaths
-- where continent is not null
group by location, population
order by infected_rate DESC;

-- Inspecting countries have the highest death cases per population
select location, population, max(total_deaths * 100/ population) as highest_death_rate, max(total_deaths) as Highest_Deaths_Count from covid_deaths
where continent is not null
group by location, population
order by Highest_Deaths_Count DESC;

-- Investigate by continent
select continent, max(total_deaths) as deaths_counted from covid_deaths
where continent is not  null
group by continent
order by deaths_counted desc; 

-- total new cases and new deaths and new deaths rate per cases
Select sum(new_cases) as total_cases, sum(new_deaths) as total_deaths, sum(new_deaths) * 100 / sum(new_cases) as new_deaths_per_cases from covid_deaths
where continent is not null
-- group by date 
order by date;

-- Create temporary table
CREATE TEMPORARY TABLE Percent_population_vaccination
(
    continent varchar(100),
    location varchar(255),
    date date,
    population bigint,
    new_vaccinations bigint,
    new_vaccinations_per_day_per_country double
);
-- Insert data
INSERT INTO Percent_population_vaccination
(
    continent, 
    location, 
    date, 
    population, 
    new_vaccinations, 
    new_vaccinations_per_day_per_country
)
-- use CTE
WITH PopvsVac (continent, location, date, population, new_vaccinations, RollingPeopleVaccinated) 
AS 
(
    SELECT 
        dea.continent,
        dea.location,
        dea.date,
        dea.population,
        vac.new_vaccinations,
        SUM(vac.new_vaccinations) OVER (PARTITION BY dea.location ORDER BY dea.location, dea.date)
    FROM covid_deaths dea
    JOIN covid_vaccinations vac
        ON dea.location = vac.location
        AND dea.date = vac.date
   --  WHERE dea.continent IS NOT NULL
)
SELECT * FROM PopvsVac;
select *, new_vaccinations_per_day_per_country * 100 / population as percent_vaccinated_per_day
from Percent_population_vaccination;

-- creating view to store date for later visualization
CREATE VIEW PercentPopulationVaccinated AS
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
SUM(vac.new_vaccinations) OVER (PARTITION BY dea.location ORDER BY dea.location, dea.date) as RollingPeopleVaccinated
FROM covid_deaths dea
JOIN vaccinations vac
    ON dea.location = vac.location
    AND dea.date = vac.date
WHERE dea.continent IS NOT NULL;

