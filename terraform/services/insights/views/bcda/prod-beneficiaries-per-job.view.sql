-- Number of beneficiaries per job request
-- NO PHI/PII allowed!
CREATE OR REPLACE VIEW bcda_prod_beneficiaries_per_job AS
select sub.job_id,
	SUM(sub.max_benes) as max_benes
from (
		select jobs.id as job_id,
			jk.resource_type,
			CASE
				WHEN jk.resource_type = 'ExplanationOfBenefit' THEN 50
				WHEN jk.resource_type = 'Patient' THEN 5000
				WHEN jk.resource_type = 'Coverage' THEN 4000
				WHEN jk.resource_type = 'Claim' THEN 4000
				WHEN jk.resource_type = 'ClaimResponse' THEN 4000
			END AS max_benes
		from jobs
			join job_keys jk ON jk.job_id = jobs.id
		where jobs.created_at > DATE(NOW() - interval '1 year')
	) sub
group by sub.job_id
order by sub.job_id;