---- check data uploaded ok
select * from WorldCovidData..CovidDeaths
order by 3,4

select * from WorldCovidData..CovidVaccinations
order by 3,4

---- Select data we want to use.
SELECT 
location, date, total_cases, new_cases, total_deaths, population
FROM WorldCovidData..CovidDeaths
where total_cases is not null
ORDER BY location, date

---- Look at total cases versus total deaths.
---- NB if continent col is null then location is a continent like Asia etc which we don't want
SELECT 
location, date, total_cases, total_deaths, (total_deaths/total_cases)*100 as percentage_deaths
--location, date, total_cases, total_deaths, Format((total_deaths/total_cases)*100, 'N3') as percentage_deaths
FROM WorldCovidData..CovidDeaths
where total_cases is not null and continent is not null 
ORDER BY 1,2

---- Look at total cases versus total deaths in UK (liklihood of dying if you contract Covid)
SELECT 
location, date, total_cases, total_deaths, (total_deaths/total_cases)*100 as percentage_deaths
FROM WorldCovidData..CovidDeaths
where total_cases is not null and continent is not null 
and location = 'United Kingdom'
ORDER BY 1,2

---- Total cases versus population
SELECT 
location, date,  population, total_cases, (total_cases/population)*100 as popln_percentage_infected
FROM WorldCovidData..CovidDeaths
where total_cases is not null and continent is not null 
and location = 'United Kingdom'
ORDER BY 1,2

---- Which countries have highest infection rate per population?
SELECT 
location,  population, MAX(total_cases) as highest_infection_count, MAX((total_cases/population)*100) as max_percent_infected
FROM WorldCovidData..CovidDeaths
where total_cases is not null and continent is not null 
GROUP BY location, population
ORDER BY max_percent_infected desc

-- Countries with highest mortality % per population
SELECT 
location, MAX(total_deaths) as max_deaths
FROM WorldCovidData..CovidDeaths
where total_cases is not null and continent is not null 
GROUP BY location
ORDER BY max_deaths desc


-- Break things down by continent (NB results indicate N America does not include Canada! So after this we do correct nrs)
SELECT 
continent, MAX(total_deaths) as max_deaths
FROM WorldCovidData..CovidDeaths
where total_cases is not null and continent is not null 
GROUP BY continent
ORDER BY max_deaths desc

-- Correct nrs by continent: use location and have continent null
SELECT 
location, MAX(total_deaths) as max_deaths
FROM WorldCovidData..CovidDeaths
where total_cases is not null and continent is  null 
AND location not in ('High income', 'Upper middle income', 'Lower middle income', 'Low income')
GROUP BY location
ORDER BY max_deaths desc


---- Global Numbers	

SELECT 
 FORMAT(SUM(new_cases), 'N0') as total_new_cases, Format(SUM(new_deaths), 'N0') as total_new_deaths, 
 SUM(new_deaths)/SUM(new_cases)*100 as percentage_deaths
FROM WorldCovidData..CovidDeaths
where total_cases is not null 
and continent is not null 
--group by date
ORDER BY 1,2 

---- Look at total population versus vaccination. 
----  Have a rolling count; partition by location so it resets at each new location.

SELECT dea.continent, dea.location, dea.date, population, vac.new_vaccinations,
	SUM(CONVERT(bigint, vac.new_vaccinations)) OVER (PARTITION BY dea.location ORDER BY dea.location, dea.date) AS RollingPeopleVaccinated
FROM WorldCovidData..CovidDeaths dea
join
WorldCovidData..CovidVaccinations vac
	ON  dea.location = vac.location
	AND dea.date = vac.date
WHERE dea.continent is not null
	ORDER BY  location, date

-- Use CTE
;
WITH PoplnVsVax (continent, location, date, population, new_vaccinations, RollingPeopleVaccinated) 
AS
(
SELECT dea.continent, dea.location, dea.date, population, vac.new_vaccinations,
	SUM(CONVERT(bigint, vac.new_vaccinations)) OVER (PARTITION BY dea.location ORDER BY dea.location, dea.date) AS RollingPeopleVaccinated
FROM WorldCovidData..CovidDeaths dea
join
WorldCovidData..CovidVaccinations vac
	ON  dea.location = vac.location
	AND dea.date = vac.date
WHERE dea.continent is not null
	--ORDER BY  location, date
)
SELECT *,  (RollingPeopleVaccinated/population)*100 AS PercentVaccinated 
from  PoplnVsVax
	ORDER BY  location, date

---- Use Temp Table
	drop table if exists #PercentPopulationVaccinated
	create table #PercentPopulationVaccinated
	(
	continent nvarchar(255),
	location nvarchar(255),
	date datetime,
	population numeric,
	new_vaccinations numeric,
	RollingPeopleVaccinated numeric
	)

	insert into #PercentPopulationVaccinated
	SELECT dea.continent, dea.location, dea.date, population, vac.new_vaccinations,
		SUM(CONVERT(bigint, vac.new_vaccinations)) OVER (PARTITION BY dea.location ORDER BY dea.location, dea.date) AS RollingPeopleVaccinated
	FROM WorldCovidData..CovidDeaths dea
	join
	WorldCovidData..CovidVaccinations vac
		ON  dea.location = vac.location
		AND dea.date = vac.date
	WHERE dea.continent is not null

SELECT *,  (RollingPeopleVaccinated/population)*100 AS PercentVaccinated 
from  #PercentPopulationVaccinated
	ORDER BY  location, date


--- Create view to store data for visualization in Tableau later.

create view PercentPopulationVaccinated AS 
	SELECT dea.continent, dea.location, dea.date, population, vac.new_vaccinations,
		SUM(CONVERT(bigint, vac.new_vaccinations)) OVER (PARTITION BY dea.location ORDER BY dea.location, dea.date) AS RollingPeopleVaccinated
	FROM WorldCovidData..CovidDeaths dea
	join
	WorldCovidData..CovidVaccinations vac
		ON  dea.location = vac.location
		AND dea.date = vac.date
	WHERE dea.continent is not null
	