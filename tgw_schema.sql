-- =====================================================
-- TGW (The Gun War) Multi-1v1 Database Schema
-- =====================================================
-- Compatible with ESX Legacy
-- Single location, multiple arenas via routing buckets
-- Arena-specific chat, no voice communication
--
-- Prerequisites: ESX users table must exist
-- Compatibility: MySQL 5.7+ or MariaDB 10.2+
-- Usage: Execute this after ESX schema installation
--
-- IMPORTANT FIXES APPLIED:
-- - Removed foreign key constraints for ESX compatibility
-- - Fixed PRIMARY KEY with NOT NULL requirement
-- - Changed JSON to TEXT for broader MySQL compatibility
-- - Used DATETIME instead of multiple TIMESTAMP columns
-- - Replaced TIMESTAMPDIFF with UNIX_TIMESTAMP for compatibility
-- =====================================================

-- Player Statistics and Data
CREATE TABLE IF NOT EXISTS `tgw_players` (
  `identifier` VARCHAR(60) NOT NULL,
  `rating` INT(11) NOT NULL DEFAULT 1500,
  `wins` INT(11) NOT NULL DEFAULT 0,
  `losses` INT(11) NOT NULL DEFAULT 0,
  `ladder_level` INT(11) NOT NULL DEFAULT 16,
  `last_seen` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`identifier`),
  INDEX `idx_rating` (`rating`),
  INDEX `idx_ladder_level` (`ladder_level`),
  INDEX `idx_last_seen` (`last_seen`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Player Preferences and Settings
CREATE TABLE IF NOT EXISTS `tgw_preferences` (
  `identifier` VARCHAR(60) NOT NULL,
  `allow_pistol` TINYINT(1) NOT NULL DEFAULT 1,
  `allow_sniper` TINYINT(1) NOT NULL DEFAULT 1,
  `preferred_round` ENUM('rifle', 'pistol', 'sniper') NOT NULL DEFAULT 'rifle',
  `fav_rifle` VARCHAR(32) NOT NULL DEFAULT 'WEAPON_CARBINERIFLE',
  `fav_pistol` VARCHAR(32) NOT NULL DEFAULT 'WEAPON_PISTOL',
  `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`identifier`),
  INDEX `idx_preferred_round` (`preferred_round`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Arena Definitions and Bucket Management
CREATE TABLE IF NOT EXISTS `tgw_arenas` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(32) NOT NULL,
  `bucket_id` INT(11) NOT NULL UNIQUE,
  `spawn_ax` FLOAT NOT NULL,
  `spawn_ay` FLOAT NOT NULL,
  `spawn_az` FLOAT NOT NULL,
  `spawn_bx` FLOAT NOT NULL,
  `spawn_by` FLOAT NOT NULL,
  `spawn_bz` FLOAT NOT NULL,
  `heading_a` FLOAT NOT NULL,
  `heading_b` FLOAT NOT NULL,
  `radius` FLOAT NOT NULL DEFAULT 30.0,
  `level` INT(11) NOT NULL DEFAULT 1,
  `active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_bucket` (`bucket_id`),
  INDEX `idx_active` (`active`),
  INDEX `idx_level` (`level`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Active Matches Tracking
CREATE TABLE IF NOT EXISTS `tgw_matches` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `arena_id` INT(11) NOT NULL,
  `player_a` VARCHAR(60) NOT NULL,
  `player_b` VARCHAR(60) NOT NULL,
  `round_type` ENUM('rifle', 'pistol', 'sniper') NOT NULL,
  `start_time` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  `end_time` TIMESTAMP NULL DEFAULT NULL,
  `winner` ENUM('a', 'b', 'draw') DEFAULT NULL,
  `status` ENUM('running', 'ended') NOT NULL DEFAULT 'running',
  `player_a_rating_before` INT(11) DEFAULT NULL,
  `player_b_rating_before` INT(11) DEFAULT NULL,
  `player_a_rating_after` INT(11) DEFAULT NULL,
  `player_b_rating_after` INT(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  INDEX `idx_arena_id` (`arena_id`),
  INDEX `idx_status` (`status`),
  INDEX `idx_start_time` (`start_time`),
  INDEX `idx_players` (`player_a`, `player_b`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Round Events and Action Logging
CREATE TABLE IF NOT EXISTS `tgw_round_events` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `match_id` INT(11) NOT NULL,
  `type` VARCHAR(32) NOT NULL, -- 'start', 'end', 'kill', 'afk', 'sudden_death', 'warn', 'forfeit'
  `actor` VARCHAR(60) DEFAULT NULL,
  `target` VARCHAR(60) DEFAULT NULL,
  `value` INT(11) DEFAULT NULL, -- damage, time, etc.
  `metadata` TEXT DEFAULT NULL, -- additional event data (JSON format)
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_match_id` (`match_id`),
  INDEX `idx_type` (`type`),
  INDEX `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Ladder Progression History
CREATE TABLE IF NOT EXISTS `tgw_ladder_logs` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `identifier` VARCHAR(60) NOT NULL,
  `before_level` INT(11) NOT NULL,
  `after_level` INT(11) NOT NULL,
  `match_id` INT(11) DEFAULT NULL,
  `reason` VARCHAR(64) DEFAULT NULL, -- 'win', 'loss', 'adjustment'
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_identifier` (`identifier`),
  INDEX `idx_match_id` (`match_id`),
  INDEX `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Rating Change History
CREATE TABLE IF NOT EXISTS `tgw_rating_logs` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `identifier` VARCHAR(60) NOT NULL,
  `before_rating` INT(11) NOT NULL,
  `after_rating` INT(11) NOT NULL,
  `delta` INT(11) NOT NULL, -- can be negative
  `match_id` INT(11) DEFAULT NULL,
  `opponent_rating` INT(11) DEFAULT NULL,
  `result` ENUM('win', 'loss', 'draw') DEFAULT NULL,
  `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_identifier` (`identifier`),
  INDEX `idx_match_id` (`match_id`),
  INDEX `idx_created_at` (`created_at`),
  INDEX `idx_result` (`result`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Queue Management
CREATE TABLE IF NOT EXISTS `tgw_queue` (
  `identifier` VARCHAR(60) NOT NULL,
  `queued_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  `state` ENUM('waiting', 'spectate', 'paired') NOT NULL DEFAULT 'waiting',
  `preferred_round` ENUM('rifle', 'pistol', 'sniper') DEFAULT NULL,
  `rating_snapshot` INT(11) DEFAULT NULL,
  `spectate_target` VARCHAR(60) DEFAULT NULL, -- who they're spectating
  `spectate_arena` INT(11) DEFAULT NULL, -- which arena they're watching
  `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`identifier`),
  INDEX `idx_state` (`state`),
  INDEX `idx_queued_at` (`queued_at`),
  INDEX `idx_rating_snapshot` (`rating_snapshot`),
  INDEX `idx_spectate_arena` (`spectate_arena`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Chat Rate Limiting
CREATE TABLE IF NOT EXISTS `tgw_chat_limits` (
  `identifier` VARCHAR(60) NOT NULL,
  `arena_id` INT(11) NOT NULL DEFAULT 0, -- 0 for global chat, arena ID for arena chat
  `message_count` INT(11) NOT NULL DEFAULT 0,
  `window_start` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `last_message` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`identifier`, `arena_id`),
  INDEX `idx_window_start` (`window_start`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================
-- Initial Data Seeding
-- =====================================================

-- Seed Arena Template Data (24 arenas with same coordinates)
-- All arenas use the same physical location but different routing buckets
INSERT INTO `tgw_arenas` (`name`, `bucket_id`, `spawn_ax`, `spawn_ay`, `spawn_az`, `spawn_bx`, `spawn_by`, `spawn_bz`, `heading_a`, `heading_b`, `radius`, `level`) VALUES
('Arena 1', 1001, 169.5, -1005.2, 29.4, 145.8, -1012.9, 29.4, 90.0, 270.0, 30.0, 1),
('Arena 2', 1002, 169.5, -1005.2, 29.4, 145.8, -1012.9, 29.4, 90.0, 270.0, 30.0, 1),
('Arena 3', 1003, 169.5, -1005.2, 29.4, 145.8, -1012.9, 29.4, 90.0, 270.0, 30.0, 1),
('Arena 4', 1004, 169.5, -1005.2, 29.4, 145.8, -1012.9, 29.4, 90.0, 270.0, 30.0, 1),
('Arena 5', 1005, 169.5, -1005.2, 29.4, 145.8, -1012.9, 29.4, 90.0, 270.0, 30.0, 1),
('Arena 6', 1006, 169.5, -1005.2, 29.4, 145.8, -1012.9, 29.4, 90.0, 270.0, 30.0, 1),
('Arena 7', 1007, 169.5, -1005.2, 29.4, 145.8, -1012.9, 29.4, 90.0, 270.0, 30.0, 1),
('Arena 8', 1008, 169.5, -1005.2, 29.4, 145.8, -1012.9, 29.4, 90.0, 270.0, 30.0, 1),
('Arena 9', 1009, 169.5, -1005.2, 29.4, 145.8, -1012.9, 29.4, 90.0, 270.0, 30.0, 1),
('Arena 10', 1010, 169.5, -1005.2, 29.4, 145.8, -1012.9, 29.4, 90.0, 270.0, 30.0, 1),
('Arena 11', 1011, 169.5, -1005.2, 29.4, 145.8, -1012.9, 29.4, 90.0, 270.0, 30.0, 1),
('Arena 12', 1012, 169.5, -1005.2, 29.4, 145.8, -1012.9, 29.4, 90.0, 270.0, 30.0, 1),
('Arena 13', 1013, 169.5, -1005.2, 29.4, 145.8, -1012.9, 29.4, 90.0, 270.0, 30.0, 1),
('Arena 14', 1014, 169.5, -1005.2, 29.4, 145.8, -1012.9, 29.4, 90.0, 270.0, 30.0, 1),
('Arena 15', 1015, 169.5, -1005.2, 29.4, 145.8, -1012.9, 29.4, 90.0, 270.0, 30.0, 1),
('Arena 16', 1016, 169.5, -1005.2, 29.4, 145.8, -1012.9, 29.4, 90.0, 270.0, 30.0, 1),
('Arena 17', 1017, 169.5, -1005.2, 29.4, 145.8, -1012.9, 29.4, 90.0, 270.0, 30.0, 1),
('Arena 18', 1018, 169.5, -1005.2, 29.4, 145.8, -1012.9, 29.4, 90.0, 270.0, 30.0, 1),
('Arena 19', 1019, 169.5, -1005.2, 29.4, 145.8, -1012.9, 29.4, 90.0, 270.0, 30.0, 1),
('Arena 20', 1020, 169.5, -1005.2, 29.4, 145.8, -1012.9, 29.4, 90.0, 270.0, 30.0, 1),
('Arena 21', 1021, 169.5, -1005.2, 29.4, 145.8, -1012.9, 29.4, 90.0, 270.0, 30.0, 1),
('Arena 22', 1022, 169.5, -1005.2, 29.4, 145.8, -1012.9, 29.4, 90.0, 270.0, 30.0, 1),
('Arena 23', 1023, 169.5, -1005.2, 29.4, 145.8, -1012.9, 29.4, 90.0, 270.0, 30.0, 1),
('Arena 24', 1024, 169.5, -1005.2, 29.4, 145.8, -1012.9, 29.4, 90.0, 270.0, 30.0, 1);

-- =====================================================
-- Optimization Indexes for Performance
-- =====================================================

-- Composite indexes for common queries
CREATE INDEX `idx_tgw_players_rating_level` ON `tgw_players` (`rating`, `ladder_level`);
CREATE INDEX `idx_tgw_matches_arena_status` ON `tgw_matches` (`arena_id`, `status`);
CREATE INDEX `idx_tgw_queue_state_rating` ON `tgw_queue` (`state`, `rating_snapshot`);
CREATE INDEX `idx_tgw_round_events_match_type` ON `tgw_round_events` (`match_id`, `type`);

-- =====================================================
-- Views for Common Queries
-- =====================================================

-- Player Statistics Summary
CREATE OR REPLACE VIEW `v_tgw_player_stats` AS
SELECT
    p.identifier,
    u.firstname,
    u.lastname,
    p.rating,
    p.wins,
    p.losses,
    p.ladder_level,
    CASE WHEN (p.wins + p.losses) > 0 THEN ROUND((p.wins / (p.wins + p.losses)) * 100, 2) ELSE 0 END as win_rate,
    p.last_seen
FROM tgw_players p
LEFT JOIN users u ON p.identifier = u.identifier;

-- Active Matches Overview
CREATE OR REPLACE VIEW `v_tgw_active_matches` AS
SELECT
    m.id as match_id,
    a.name as arena_name,
    a.bucket_id,
    m.player_a,
    m.player_b,
    m.round_type,
    m.start_time,
    UNIX_TIMESTAMP(NOW()) - UNIX_TIMESTAMP(m.start_time) as duration_seconds,
    ua.firstname as player_a_name,
    ub.firstname as player_b_name
FROM tgw_matches m
LEFT JOIN tgw_arenas a ON m.arena_id = a.id
LEFT JOIN users ua ON m.player_a = ua.identifier
LEFT JOIN users ub ON m.player_b = ub.identifier
WHERE m.status = 'running';

-- Queue Status Overview
CREATE OR REPLACE VIEW `v_tgw_queue_status` AS
SELECT
    q.identifier,
    u.firstname,
    q.state,
    q.preferred_round,
    q.rating_snapshot,
    q.queued_at,
    UNIX_TIMESTAMP(NOW()) - UNIX_TIMESTAMP(q.queued_at) as wait_time_seconds,
    CASE WHEN q.spectate_arena IS NOT NULL THEN CONCAT('Arena ', (SELECT name FROM tgw_arenas WHERE id = q.spectate_arena)) ELSE NULL END as spectating
FROM tgw_queue q
LEFT JOIN users u ON q.identifier = u.identifier;

-- =====================================================
-- Stored Procedures for Common Operations
-- =====================================================

DELIMITER //

-- Initialize new player in TGW system
CREATE PROCEDURE sp_tgw_init_player(IN p_identifier VARCHAR(60))
BEGIN
    INSERT INTO tgw_players (identifier, rating, wins, losses, ladder_level)
    VALUES (p_identifier, 1500, 0, 0, 16)
    ON DUPLICATE KEY UPDATE last_seen = CURRENT_TIMESTAMP;

    INSERT INTO tgw_preferences (identifier, allow_pistol, allow_sniper, preferred_round, fav_rifle, fav_pistol)
    VALUES (p_identifier, 1, 1, 'rifle', 'WEAPON_CARBINERIFLE', 'WEAPON_PISTOL')
    ON DUPLICATE KEY UPDATE updated_at = CURRENT_TIMESTAMP;
END //

-- Clean up old completed matches (older than 7 days)
CREATE PROCEDURE sp_tgw_cleanup_old_matches()
BEGIN
    DELETE FROM tgw_matches
    WHERE status = 'ended'
    AND end_time < DATE_SUB(NOW(), INTERVAL 7 DAY);
END //

-- Get leaderboard by rating
CREATE PROCEDURE sp_tgw_get_leaderboard(IN p_limit INT)
BEGIN
    SELECT
        identifier,
        firstname,
        lastname,
        rating,
        wins,
        losses,
        ladder_level,
        win_rate
    FROM v_tgw_player_stats
    ORDER BY rating DESC
    LIMIT p_limit;
END //

DELIMITER ;

-- =====================================================
-- Success Message
-- =====================================================

SELECT 'TGW Database Schema Successfully Created!' as Status,
       (SELECT COUNT(*) FROM tgw_arenas) as ArenaCount,
       'All tables, indexes, views, and procedures created successfully' as Message;