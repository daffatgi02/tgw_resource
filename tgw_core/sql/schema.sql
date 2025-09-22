-- =====================================================
-- TGW CORE SCHEMA REFERENCE
-- =====================================================
-- This file contains the database schema that should be
-- executed before starting the TGW system
--
-- IMPORTANT: Run the main tgw_schema.sql file located
-- in the resources root directory before starting TGW
-- =====================================================

-- This is a reference copy of the schema
-- Execute the main schema file: ../tgw_schema.sql

/*
Tables created by tgw_schema.sql:

1. tgw_players - Player statistics and data
2. tgw_preferences - Player preferences and settings
3. tgw_arenas - Arena definitions and bucket management
4. tgw_matches - Active matches tracking
5. tgw_round_events - Round events and action logging
6. tgw_ladder_logs - Ladder progression history
7. tgw_rating_logs - Rating change history
8. tgw_queue - Queue management
9. tgw_chat_limits - Chat rate limiting

Views created:
- v_tgw_player_stats - Player statistics summary
- v_tgw_active_matches - Active matches overview
- v_tgw_queue_status - Queue status overview

Stored procedures created:
- sp_tgw_init_player - Initialize new player
- sp_tgw_cleanup_old_matches - Clean up old match data
- sp_tgw_get_leaderboard - Get player leaderboard

Initial data:
- 24 arenas seeded with identical coordinates
- Bucket IDs from 1001-1024
*/

-- To execute the full schema, run:
-- mysql -u username -p database_name < ../tgw_schema.sql

-- Or via oxmysql resource:
-- Execute the SQL content from tgw_schema.sql file