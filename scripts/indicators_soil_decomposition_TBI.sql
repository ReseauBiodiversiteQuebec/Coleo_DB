CREATE SCHEMA IF NOT EXISTS indicators;

-------------------------------------------------------------------------------
-- VIEW indicators.soil_decomposition_TBI
-- DESCRIPTION List of soil decomposition TBI (tea bags indicator)
-- TBI consists of two indicators : s and k
-------------------------------------------------------------------------------

-- CREATE VIEW TO COMPUTE SOIL DECOMPOSITION INDICATORS
CREATE OR REPLACE VIEW indicators.soil_decomposition_TBI AS (
    WITH const AS (
        SELECT 0.842 AS Hg, 0.552 AS Hr -- Hg = 0.842, Hr = 0.552
    ), tea_bags AS (
        SELECT campaign_id,
            observation_id,
            obs_soil_decomposition.bag_no,
            obs_soil_decomposition.type,
            campaigns.opened_at AS start,
            campaigns.closed_at AS end,
            campaigns.closed_at - campaigns.opened_at AS t,
            shading, human_impact,
            obs_soil_decomposition.start_weight,
            obs_soil_decomposition.end_weight_with_bag,
            obs_soil_decomposition.end_weight_tea
        FROM obs_soil_decomposition, campaigns, observations
        WHERE campaigns.id = observations.campaign_id
            and observations.id = obs_soil_decomposition.observation_id
            and observations.id = obs_soil_decomposition.observation_id
    ), s AS (
        SELECT campaign_id,
            start, tea_bags.end, t, -- Should all be the same within campaings
            avg(start_weight) AS avg_tv_start_weight,
            avg(end_weight_with_bag) AS avg_tv_end_weight_with_bag,
            avg(end_weight_tea) AS avg_tv_end_weight_tea,
            ((avg(end_weight_tea) / (avg(start_weight) - (avg(end_weight_with_bag) - avg(end_weight_tea)))) / min(const.Hg)) AS s
        FROM tea_bags, const
        WHERE type = 'thé vert'
        GROUP BY campaign_id, start, tea_bags.end, t
    ), k AS (
        SELECT tea_bags.campaign_id AS campaign_id,
            avg(start_weight) AS avg_tr_start_weight,
            avg(end_weight_with_bag) AS avg_tr_end_weight_with_bag,
            avg(end_weight_tea) AS avg_tr_end_weight_tea,
            s,
            ln (CASE WHEN (avg(end_weight_with_bag) / (avg(start_weight) - (avg(end_weight_with_bag) - avg(end_weight_tea)))) < (1 - (const.Hr * (1 - s.s))) THEN NULL ELSE (const.Hr * (1 - s.s)) / ((avg(end_weight_with_bag) / (avg(start_weight) - (avg(end_weight_with_bag) - avg(end_weight_tea)))) - (1 - (const.Hr * (1 - s.s)))) end) AS k
        FROM tea_bags, const, s
        WHERE tea_bags.type = 'rooibos'
            and s.campaign_id = tea_bags.campaign_id
        GROUP BY tea_bags.campaign_id, const.Hr, s.s, s.t
    ) 
    SELECT s.campaign_id,
        s.start, s.end, s.t, 
        avg_tv_start_weight,
        avg_tv_end_weight_with_bag,
        avg_tv_end_weight_tea,
        avg_tr_start_weight,
        avg_tr_end_weight_with_bag,
        avg_tr_end_weight_tea,
        s.s, k.k
    FROM k, s 
    WHERE k.campaign_id = s.campaign_id
    ORDER BY s.start
);
