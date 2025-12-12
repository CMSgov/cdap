CREATE VIEW ab2d_prod_benes_searched AS
select *, contract_number as "Contract Number",
contract_name  as "Contract Name",
job_uuid as "Job ID",
benes_searched as "# Bene Searched",
completed_at as "Completed At",
eobs_written as "# EoBs Written",
data_start_time as "Data Start Date (Since Date)",
fhir_version as "FHIR Version",
to_char(time_to_complete, 'HH24:MI:SS') as "Seconds Run",
created_at as "Job Start Time",
completed_at as "Job Complete Time",
to_char(time_to_complete, 'HH24:MI:SS') as sec_run,
created_at as job_start_time,
completed_at as job_complete_time
from (
select s.contract_number, c.contract_name, j.job_uuid, s.benes_searched, j.created_at, j.completed_at, s.eobs_written,
j.completed_at - j.created_at as time_to_complete,
CASE
    WHEN j.since is null THEN
        CASE
            WHEN c.attested_on < '2020-01-01'
            THEN '2020-01-01'
            ELSE c.attested_on
        END
    ELSE j.since
end as data_start_time, j.since, j.fhir_version, j.status
from job j
left join event.event_bene_search s on s.job_id = j.job_uuid
left join contract_view c on c.contract_number = j.contract_number and c.contract_name is not null
where j.started_by='PDP') t
order by "Job Start Time" desc
