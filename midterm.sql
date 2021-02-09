-- A system is being developed for tracking of project tasks works by company employees. 
-- After connecting to the system, each company registers its employees (username, password, full name, email, position). 
-- Access of retired employees to the system must be prohibited, but all their data must be persisted. Each company performs projects for its clients. 
-- The client has a long and short name, INN, and email address. Each project is executed for single client. The project has a name, start date, and end date. 
-- Project work is performed according to the plan in the form of a set of tasks (the task has a name and category), defined at the beginning of the project. 
-- Each project is assigned to a group of employees (the others cannot work on this project). An employee can be assigned to multiple projects. 
-- Every working day, the employee selects one of the available projects, then selects one of the unfinished tasks for this project, 
-- and marks in the system that he takes this task to work, starting from the current time. When the task is completed, 
-- the employee marks this fact in the system with a record of the time when the work was completed. If the task is blocked (for example, we are waiting for the client's response) or paused, 
-- the employee marks the fact that work on this task has been suspended at this moment, and selects any other available task from the available projects.

-- Task 1 (2 pt): Design a relational database, draw an ER diagram (optional), 
-- and write a tables creation script (required).

create table companies(
    inn number(10) primary key,
    name varchar(256)
);

create table clients(
    inn number(10) primary key,
    long_name varchar(256),
    short_name varchar(256),
    email varchar(256)
);

create table employees(
    company_inn number(10),
    username varchar(256),
    password varchar(256),
    full_name varchar(256),
    email varchar(256),
    position_ varchar(256),

    foreign key(company_inn)
        references companies(inn)
        on delete cascade,
    
    primary key(company_inn, username)
);

create table projects(
    company_inn number(10),
    client_inn number(10),
    name varchar(256),
    start_date date,
    end_date date,

    foreign key(company_inn)
        references companies(inn)
        on delete cascade,
    
    foreign key(client_inn)
        references clients(inn)
        on delete cascade,

    primary key(company_inn, client_inn, name)
);

create table employees_distribution(
    company_inn number(10),
    client_inn number(10),
    project_name varchar(256),
    employee_username varchar(256),

    foreign key(company_inn, client_inn, project_name)
        references projects(company_inn, client_inn, name)
        on delete cascade,

    foreign key(company_inn, employee_username)
        references employees(company_inn, username)
        on delete cascade,

    primary key(company_inn, client_inn, project_name, employee_username)
);

create table tasks(
    company_inn number(10),
    client_inn number(10),
    project_name varchar(256),
    name varchar(256),
    category varchar(256),

    foreign key(company_inn, client_inn, project_name)
        references projects(company_inn, client_inn, name)
        on delete cascade,

    primary key(company_inn, client_inn, project_name, name)
);

create table task_events(
    task_id number(20), 
    company_inn number(10),
    client_inn number(10),
    project_name varchar(256),
    employee_username varchar(256),
    task_name varchar(256),
    start_date date,
    end_date date,
    end_status varchar(256),

    foreign key(company_inn, client_inn, project_name, employee_username)
        references employees_distribution(company_inn, client_inn, project_name, employee_username)
        on delete cascade,
    
    foreign key(company_inn, client_inn, project_name, task_name)
        references tasks(company_inn, client_inn, project_name, name)
        on delete cascade,
    
    primary key(task_id)
);

-- Task 2 (2 pt): Write an SQL query that returns a list of employees for a given company, 
-- and for each employee - the total amount of time spent on all tasks for all projects for the specified calendar month.

with task_events_ as (
    select task_id, company_inn, 
        client_inn, project_name, 
        employee_username, task_name, 
        start_date, end_status,
        case when end_date is null then current_date else end_date end as end_date
    from task_events
)
select employees.username, case when hours is null then 0 else hours end as hours
from employees employees left join 
(select employee_username,
       round(sum(case when start_date < trunc(add_months(to_date('06-2016', 'MM-YYYY'), 1), 'MM')
                  and end_date > trunc(to_date('06-2016', 'MM-YYYY'), 'MM') 
                  then least(end_date, trunc(add_months(to_date('06-2016', 'MM-YYYY'), 1), 'MM')) 
                     - greatest(start_date, trunc(to_date('06-2016', 'MM-YYYY'), 'MM')) 
                  else 0 end) * 24) as hours
from task_events_
where company_inn = 3
group by employee_username) hours_per_employee
on employees.company_inn = 3
and employees.username = hours_per_employee.employee_username

-- Task 3 (2 pt): Write an SQL query that returns a list of employees for a given company, and for each employee, 
-- the total amount of time they spent on each client (all tasks for all projects of this client) for the specified calendar month.

with task_events_ as (
    select task_id, company_inn, 
        client_inn, project_name, 
        employee_username, task_name, 
        start_date, end_status,
        case when end_date is null then current_date else end_date end as end_date
    from task_events
)
select employees_clients.username, employees_clients.client_inn, case when hours is null then 0 else hours end
from (
    select username, client_inn
    from employees e cross join projects p
    where e.company_inn = 3 and p.company_inn = 3 
) employees_clients
left join (
    select employee_username, 
          client_inn,
          round(sum(case when start_date < trunc(add_months(to_date('06-2016', 'MM-YYYY'), 1), 'MM')
                 and end_date > trunc(to_date('06-2016', 'MM-YYYY'), 'MM') 
                 then least(end_date, trunc(add_months(to_date('06-2016', 'MM-YYYY'), 1), 'MM')) 
                    - greatest(start_date, trunc(to_date('06-2016', 'MM-YYYY'), 'MM')) 
                 else 0 end) * 24) as hours
    from task_events_
    where company_inn = 3
    group by employee_username, client_inn
) hours_per_employee_per_client
on employees_clients.username = hours_per_employee_per_client.employee_username
and employees_clients.client_inn = hours_per_employee_per_client.client_inn
order by employees_clients.username, employees_clients.client_inn

-- Task 4 (2 pt): Write an SQL query that returns for each task category the number of projects (done by different companies) 
-- in each of which tasks in this category occurred at least three times, and the total amount of time spent on all tasks 
-- in this category for the specified calendar year. 

with task_events_ as (
    select task_id, company_inn, 
        client_inn, project_name, 
        employee_username, task_name, 
        start_date, end_status,
        case when end_date is null then current_date else end_date end as end_date
    from task_events
)
select projects_per_category.category, projects_count, total_hours
from(
    (
        select category, count(1) as projects_count
        from(
            select  p.name as project_name,
                    t.category as category,
                    count(1) as tasks_count
            from projects p join tasks t
            on p.company_inn = t.company_inn 
            and p.client_inn = t.client_inn
            and p.name = t.project_name
            group by p.company_inn, p.client_inn, p.name, t.category
            having count(1) > 2
        )
        group by category
    ) projects_per_category 
    join (
        select  category, 
                round(sum(end_date - start_date) * 24) as total_hours
        from tasks t join task_events_ te
        on t.company_inn = te.company_inn 
        and t.client_inn = te.client_inn
        and t.name = te.task_name
        and extract(year from te.end_date) = extract(year from to_date('2020', 'YYYY'))
        group by category
    ) hours_per_category
    on projects_per_category.category = hours_per_category.category
)

-- Task 5 (2 pt):  Write an SQL query that returns all employees who successfully worked on each project (completed at least one task from each project) 
-- for their company in the specified calendar year.

with task_events_ as (
    select task_id, company_inn, 
        client_inn, project_name, 
        employee_username, task_name, 
        start_date, end_status,
        case when end_date is null then current_date else end_date end as end_date
    from task_events
)
select company_inn, employee_username
from(
    select company_inn, employee_username, client_inn, project_name
    from task_events_
    where end_status = 'completed' and extract(year from end_date) = extract(year from to_date('2016', 'YYYY'))
    group by company_inn, employee_username, client_inn, project_name
) t
group by company_inn, employee_username
having count(1) = (select count(1) from projects 
                  where t.company_inn = company_inn)

--  Task 6 (2 pt): Write an SQL query that returns all projects where no task was completed on the first attempt.

select company_inn, client_inn, project_name
from(
    select  company_inn, 
            client_inn, 
            project_name, 
            sum(case 
                when end_status in ('suspended', 'blocked') then  1
                else 0 end) as attempts
    from task_events
    group by company_inn, client_inn, project_name, task_name
)
group by company_inn, client_inn, project_name
having min(attempts) > 1