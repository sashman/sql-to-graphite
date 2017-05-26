IF OBJECT_ID('tempdb..#USIntermediateUsers') IS NOT NULL DROP TABLE #USIntermediateUsers; IF OBJECT_ID('tempdb..#USIntermediateUsersWithManagedHint') IS NOT NULL DROP TABLE #USIntermediateUsersWithManagedHint; IF OBJECT_ID('tempdb..#ShowMeTheMoney') IS NOT NULL DROP TABLE #ShowMeTheMoney; DECLARE @PeriodStart DATETIME; DECLARE @PeriodEnd DATETIME; DECLARE @AnalysisDate DATETIME; DECLARE @AnalysisWindow int; SET @AnalysisDate = DATEADD(MONTH, -6, GETDATE()); SET @AnalysisWindow = 30; SET @PeriodStart = CONVERT(DATE, @AnalysisDate); SET @PeriodEnd = DATEADD(MILLISECOND, -2, DATEADD(DAY, 1, @PeriodStart)); SELECT * INTO #USIntermediateUsers FROM ( SELECT MemberKey, MemberRegisteredOn, TreeCreatedOn, RowNumber, TreeStatusId, TreeStatusNote, TreeId FROM ( SELECT member_key AS MemberKey, member.date_created AS MemberRegisteredOn, TreeStatusId, TreeStatusNote, tree.DateCreated AS TreeCreatedOn, tree.Id AS TreeId, RANK() OVER (PARTITION BY RelationServiceMemberId ORDER BY tree.DateCreated ASC) AS RowNumber FROM [Data_FMP]..[all_member] AS member LEFT JOIN [Data_Tree]..[RelationServiceMember] AS rsm ON rsm.MemberKey = member.member_key INNER JOIN [Data_Tree]..[FamilyTree] AS tree ON tree.RelationServiceMemberId = rsm.Id WHERE member.date_created BETWEEN @PeriodStart AND @PeriodEnd AND member.partnership_key = 10 ) AS DateOrderedTrees WHERE DateOrderedTrees.RowNumber = 1 AND (DateOrderedTrees.TreeStatusId = 11 AND DateOrderedTrees.TreeStatusNote LIKE 'Gedcom%') AND TreeCreatedOn < DATEADD(DAY, @AnalysisWindow, MemberRegisteredOn) ) AS funnel_1; SELECT * INTO #USIntermediateUsersWithManagedHint FROM ( SELECT MemberKey, MemberRegisteredOn, ManagedFirstHintOn FROM ( SELECT MemberKey, MemberRegisteredOn, DateUpdated AS ManagedFirstHintOn, RANK() OVER(PARTITION BY MemberKey ORDER BY DateUpdated ASC) AS HintNumber FROM ( SELECT * FROM #USIntermediateUsers users LEFT JOIN [Data_Tree]..[PersonHint] AS hint ON hint.FamilyTreeId = users.TreeId WHERE hint.HintStatusId != 0 ) AS ranked_hints ) AS members_with_hints WHERE HintNumber = 1 AND ManagedFirstHintOn < DATEADD(DAY, @AnalysisWindow, MemberRegisteredOn) ) AS funnel_2; SELECT * INTO #ShowMeTheMoney FROM ( SELECT users_with_hints.MemberKey AS MemberKey, trans.currency_amount, trans.package_key FROM #USIntermediateUsersWithManagedHint users_with_hints LEFT JOIN [Data_FMP]..[member_trans] AS trans ON trans.member_key = users_with_hints.MemberKey WHERE trans.trans_added_date < DATEADD(DAY, @AnalysisWindow, MemberRegisteredOn) AND trans.trans_added_date > ManagedFirstHintOn AND trans.trans_status_key = 20 AND trans.currency_amount > 0 GROUP BY users_with_hints.MemberKey, trans.currency_amount, trans.package_key ) AS funnel_3; DECLARE @StatsTable TABLE ( GraphitePath VARCHAR(256), MemberCount int, [Timestamp] int ); DECLARE @Timestamp int; SET @Timestamp = DATEDIFF(SECOND,{d '1970-01-01'}, @PeriodStart); INSERT INTO @StatsTable SELECT 'test.funnels.hints.window.' + RTRIM(CONVERT(char, @AnalysisWindow)) + '_days.stage_1', (SELECT COUNT(*) FROM #USIntermediateUsers), @Timestamp; INSERT INTO @StatsTable SELECT 'test.funnels.hints.window.' + RTRIM(CONVERT(char, @AnalysisWindow)) + '_days.stage_2', (SELECT COUNT(*) FROM #USIntermediateUsersWithManagedHint), @Timestamp; INSERT INTO @StatsTable SELECT 'test.funnels.hints.window.' + RTRIM(CONVERT(char, @AnalysisWindow)) + '_days.stage_3', (SELECT COUNT(*) FROM #ShowMeTheMoney), @Timestamp; SELECT * FROM @StatsTable; DROP TABLE #USIntermediateUsers; DROP TABLE #USIntermediateUsersWithManagedHint; DROP TABLE #ShowMeTheMoney;
