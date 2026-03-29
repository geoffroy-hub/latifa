-- ============================================================
--  Miralocks — Configuration MASTER COMPLÈTE
--  Version : 3.0 (Mise à jour du 22/03/2026)
--  Inclut : Services, Dashboard, WhatsApp CallMeBot, Rappels cron
-- ============================================================

-- 1. TABLES DE BASE
CREATE TABLE IF NOT EXISTS public.settings (
  cle TEXT PRIMARY KEY, valeur TEXT, modifie_le TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.blog_posts (
  id BIGSERIAL PRIMARY KEY, titre TEXT NOT NULL, extrait TEXT, contenu TEXT,
  photo_url TEXT, categorie TEXT DEFAULT 'Conseil', slug TEXT,
  publie BOOLEAN DEFAULT false, created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.galerie_photos (
  id BIGSERIAL PRIMARY KEY, titre TEXT, description TEXT, photo_url TEXT NOT NULL,
  categorie TEXT DEFAULT 'creation', ordre INTEGER DEFAULT 0,
  publie BOOLEAN DEFAULT true, created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.galerie_videos (
  id BIGSERIAL PRIMARY KEY, titre TEXT NOT NULL, description TEXT,
  video_url TEXT NOT NULL, thumbnail_url TEXT,
  publie BOOLEAN DEFAULT true, created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.avis_clients (
  id BIGSERIAL PRIMARY KEY, nom TEXT NOT NULL, localite TEXT DEFAULT 'Lomé, Togo',
  etoiles SMALLINT DEFAULT 5 CHECK (etoiles >= 1 AND etoiles <= 5),
  texte TEXT NOT NULL, approuve BOOLEAN DEFAULT false, created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. PRESTATIONS (SERVICES)
CREATE TABLE IF NOT EXISTS public.services (
  id BIGSERIAL PRIMARY KEY, nom TEXT NOT NULL, description TEXT,
  prix TEXT, categorie TEXT DEFAULT 'Autres', ordre INTEGER DEFAULT 0,
  actif BOOLEAN DEFAULT true, created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. RENDEZ-VOUS (avec email + WhatsApp CallMeBot)
CREATE TABLE IF NOT EXISTS public.rendezvous (
  id                 BIGSERIAL PRIMARY KEY,
  nom                TEXT NOT NULL,
  tel                TEXT NOT NULL,
  email              TEXT,
  whatsapp_callmebot TEXT,
  callmebot_apikey   TEXT,
  service            TEXT NOT NULL,
  date_rdv           DATE NOT NULL,
  heure              TEXT,
  message            TEXT,
  photo_url          TEXT,
  statut             TEXT DEFAULT 'en_attente' CHECK (statut IN ('en_attente','confirme','annule','termine')),
  note_admin         TEXT,
  created_at         TIMESTAMPTZ DEFAULT NOW()
);

-- 4. PERMISSIONS
GRANT SELECT, INSERT ON public.avis_clients TO anon;
GRANT SELECT, INSERT ON public.rendezvous   TO anon;
GRANT SELECT ON public.blog_posts           TO anon;
GRANT SELECT ON public.galerie_photos       TO anon;
GRANT SELECT ON public.galerie_videos       TO anon;
GRANT SELECT ON public.services             TO anon;
GRANT SELECT ON public.settings             TO anon;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO anon;
GRANT ALL ON ALL TABLES    IN SCHEMA public TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- 5. RLS
ALTER TABLE blog_posts     ENABLE ROW LEVEL SECURITY;
ALTER TABLE galerie_photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE galerie_videos ENABLE ROW LEVEL SECURITY;
ALTER TABLE avis_clients   ENABLE ROW LEVEL SECURITY;
ALTER TABLE rendezvous     ENABLE ROW LEVEL SECURITY;
ALTER TABLE services       ENABLE ROW LEVEL SECURITY;
ALTER TABLE settings       ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "read_public_blog"         ON blog_posts;
DROP POLICY IF EXISTS "admin_all_blog"            ON blog_posts;
CREATE POLICY "read_public_blog" ON blog_posts FOR SELECT USING (publie = true);
CREATE POLICY "admin_all_blog"   ON blog_posts FOR ALL USING (auth.role()='authenticated') WITH CHECK (auth.role()='authenticated');

DROP POLICY IF EXISTS "read_public_galerie"      ON galerie_photos;
DROP POLICY IF EXISTS "admin_all_galerie"         ON galerie_photos;
CREATE POLICY "read_public_galerie" ON galerie_photos FOR SELECT USING (publie = true);
CREATE POLICY "admin_all_galerie"   ON galerie_photos FOR ALL USING (auth.role()='authenticated') WITH CHECK (auth.role()='authenticated');

DROP POLICY IF EXISTS "read_public_videos"       ON galerie_videos;
DROP POLICY IF EXISTS "admin_all_videos"          ON galerie_videos;
CREATE POLICY "read_public_videos" ON galerie_videos FOR SELECT USING (publie = true);
CREATE POLICY "admin_all_videos"   ON galerie_videos FOR ALL USING (auth.role()='authenticated') WITH CHECK (auth.role()='authenticated');

DROP POLICY IF EXISTS "read_public_avis"         ON avis_clients;
DROP POLICY IF EXISTS "insert_public_avis"        ON avis_clients;
DROP POLICY IF EXISTS "admin_all_avis"            ON avis_clients;
CREATE POLICY "read_public_avis"   ON avis_clients FOR SELECT USING (approuve = true);
CREATE POLICY "insert_public_avis" ON avis_clients FOR INSERT WITH CHECK (true);
CREATE POLICY "admin_all_avis"     ON avis_clients FOR ALL USING (auth.role()='authenticated') WITH CHECK (auth.role()='authenticated');

DROP POLICY IF EXISTS "insert_public_rdv"        ON rendezvous;
DROP POLICY IF EXISTS "admin_all_rdv"             ON rendezvous;
CREATE POLICY "insert_public_rdv" ON rendezvous FOR INSERT WITH CHECK (true);
CREATE POLICY "admin_all_rdv"     ON rendezvous FOR ALL USING (auth.role()='authenticated') WITH CHECK (auth.role()='authenticated');

DROP POLICY IF EXISTS "public_read_services"     ON services;
DROP POLICY IF EXISTS "admin_all_services_total"  ON services;
CREATE POLICY "public_read_services"     ON services FOR SELECT USING (true);
CREATE POLICY "admin_all_services_total" ON services FOR ALL USING (auth.role()='authenticated') WITH CHECK (true);

DROP POLICY IF EXISTS "read_public_settings"     ON settings;
DROP POLICY IF EXISTS "admin_all_settings"        ON settings;
CREATE POLICY "read_public_settings" ON settings FOR SELECT USING (true);
CREATE POLICY "admin_all_settings"   ON settings FOR ALL USING (auth.role()='authenticated') WITH CHECK (auth.role()='authenticated');

-- 6. STORAGE (bucket: Miralocks-media — créer via Dashboard → Storage → New bucket → Public)
DROP POLICY IF EXISTS "lecture_publique_storage" ON storage.objects;
DROP POLICY IF EXISTS "envoi_publique_rdv"        ON storage.objects;
DROP POLICY IF EXISTS "admin_total_storage"       ON storage.objects;
CREATE POLICY "lecture_publique_storage" ON storage.objects FOR SELECT USING (bucket_id='Miralocks-media');
CREATE POLICY "envoi_publique_rdv"       ON storage.objects FOR INSERT WITH CHECK (bucket_id='Miralocks-media');
CREATE POLICY "admin_total_storage"      ON storage.objects FOR ALL
  USING (bucket_id='Miralocks-media' AND auth.role()='authenticated')
  WITH CHECK (bucket_id='Miralocks-media' AND auth.role()='authenticated');

-- 7. ANTI-SPAM (TRIGGERS)
-- Avis : 15 max par heure
CREATE OR REPLACE FUNCTION check_avis_limit() RETURNS TRIGGER AS $$
BEGIN
  IF (SELECT count(*) FROM avis_clients WHERE created_at > NOW() - INTERVAL '1 hour') >= 15 THEN
    RAISE EXCEPTION 'Trop d''avis soumis. Réessayez plus tard.';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS trigger_avis_limit ON avis_clients;
CREATE TRIGGER trigger_avis_limit BEFORE INSERT ON avis_clients FOR EACH ROW EXECUTE FUNCTION check_avis_limit();

-- RDV : 2 max par jour par même téléphone
CREATE OR REPLACE FUNCTION check_rdv_limit() RETURNS TRIGGER AS $$
BEGIN
  IF (SELECT count(*) FROM rendezvous WHERE tel = NEW.tel AND created_at > NOW() - INTERVAL '1 day') >= 2 THEN
    RAISE EXCEPTION 'Trop de demandes. Réessayez demain.';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS trigger_rdv_limit ON rendezvous;
CREATE TRIGGER trigger_rdv_limit BEFORE INSERT ON rendezvous FOR EACH ROW EXECUTE FUNCTION check_rdv_limit();

-- 8. INDEX (Performances)
CREATE INDEX IF NOT EXISTS idx_rdv_date     ON rendezvous (date_rdv DESC);
CREATE INDEX IF NOT EXISTS idx_rdv_statut   ON rendezvous (statut);
CREATE INDEX IF NOT EXISTS idx_services_ord ON services (ordre ASC);
CREATE INDEX IF NOT EXISTS idx_blog_date    ON blog_posts (created_at DESC);

-- 9. CRON JOB — Rappels WhatsApp 24h avant (9h Lomé = 8h UTC)
CREATE EXTENSION IF NOT EXISTS pg_cron;
SELECT cron.schedule(
  'rappels-rdv-quotidiens', '0 8 * * *',
  $$SELECT net.http_post(
    url := 'https://mqityrifhiaarwdcacxo.supabase.co/functions/v1/send-reminders',
    headers := '{"Content-Type":"application/json","apikey":"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1xaXR5cmlmaGlhYXJ3ZGNhY3hvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQxMTYwMDEsImV4cCI6MjA4OTY5MjAwMX0.sYsUB9AWPXrsRDnz8YxEQiZOh7USxP2W_QNrZyU3mpE"}'::jsonb,
    body := '{}'::jsonb
  );$$
);

-- ══════════════════════════════════════════
-- EDGE FUNCTIONS (déployées automatiquement)
-- ══════════════════════════════════════════
-- send-confirmation (v2) : email de confirmation client + notif admin
-- send-reminders (v1)    : rappels WhatsApp CallMeBot chaque matin à 9h
