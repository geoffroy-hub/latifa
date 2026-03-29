# 🚀 Guide de configuration Supabase — Miralocks

## ÉTAPE 1 — Créer votre projet Supabase

1. Allez sur **https://supabase.com** → "Start for free"
2. Créez un compte (gratuit)
3. Cliquez **"New project"**
   - Nom : `Miralocks`
   - Mot de passe : choisissez-en un fort (notez-le !)
   - Région : `West EU (Ireland)` (le plus proche de l'Afrique de l'Ouest)
4. Attendez ~2 minutes que le projet soit créé

---

## ÉTAPE 2 — Récupérer vos clés API

1. Dans votre projet → **Settings** → **API**
2. Copiez :
   - **Project URL** → ex: `https://abcdefgh.supabase.co`
   - **anon / public key** → longue chaîne commençant par `eyJ...`

3. Ouvrez le fichier **`js/supabase.js`** et remplacez :
```javascript
const SUPABASE_URL  = 'https://VOTRE_URL.supabase.co';
const SUPABASE_ANON = 'VOTRE_CLE_ANON_PUBLIC';
```

---

## ÉTAPE 3 — Créer le compte administrateur

1. Dans Supabase → **Authentication** → **Users**
2. Cliquez **"Invite user"** ou **"Add user"**
3. Entrez votre email admin (ex: `admin@Miralocks.com`)
4. Choisissez un mot de passe fort
5. ✅ Ce sont les identifiants pour vous connecter à `admin.html`

---

## ÉTAPE 4 — Créer les tables (base de données)

1. Supabase → **SQL Editor** → **"New query"**
2. Copiez-collez ce SQL et cliquez **"Run"** :

```sql
-- ══════════════════════════════════════════
-- TABLE : Paramètres site (clé Maps, etc.)
-- ══════════════════════════════════════════
CREATE TABLE site_settings (
  id         TEXT PRIMARY KEY,
  valeur     TEXT NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```
CREATE TABLE blog_posts (
  id          BIGSERIAL PRIMARY KEY,
  titre       TEXT NOT NULL,
  extrait     TEXT,
  contenu     TEXT,
  photo_url   TEXT,
  categorie   TEXT DEFAULT 'Conseil',
  slug        TEXT,
  publie      BOOLEAN DEFAULT false,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ══════════════════════════════════════════
-- TABLE : Galerie Photos
-- ══════════════════════════════════════════
CREATE TABLE galerie_photos (
  id          BIGSERIAL PRIMARY KEY,
  titre       TEXT,
  description TEXT,
  photo_url   TEXT NOT NULL,
  categorie   TEXT DEFAULT 'creation',
  ordre       INTEGER DEFAULT 0,
  publie      BOOLEAN DEFAULT true,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ══════════════════════════════════════════
-- TABLE : Vidéos
-- ══════════════════════════════════════════
CREATE TABLE galerie_videos (
  id            BIGSERIAL PRIMARY KEY,
  titre         TEXT NOT NULL,
  description   TEXT,
  video_url     TEXT NOT NULL,
  thumbnail_url TEXT,
  duree         TEXT,
  publie        BOOLEAN DEFAULT true,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ══════════════════════════════════════════
-- TABLE : Avis Clients
-- ══════════════════════════════════════════
CREATE TABLE avis_clients (
  id         BIGSERIAL PRIMARY KEY,
  nom        TEXT NOT NULL,
  localite   TEXT DEFAULT 'Lomé, Togo',
  etoiles    SMALLINT DEFAULT 5 CHECK (etoiles >= 1 AND etoiles <= 5),
  texte      TEXT NOT NULL,
  approuve   BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

## ÉTAPE 5 — Configurer les permissions (Row Level Security)

Toujours dans **SQL Editor**, exécutez :

```sql
-- Activer RLS sur toutes les tables
ALTER TABLE blog_posts      ENABLE ROW LEVEL SECURITY;
ALTER TABLE galerie_photos  ENABLE ROW LEVEL SECURITY;
ALTER TABLE galerie_videos  ENABLE ROW LEVEL SECURITY;
ALTER TABLE avis_clients    ENABLE ROW LEVEL SECURITY;
ALTER TABLE site_settings   ENABLE ROW LEVEL SECURITY;

-- ── Lecture publique (site visible par tous) ──
CREATE POLICY "public_read_blog"     ON blog_posts      FOR SELECT USING (publie = true);
CREATE POLICY "public_read_galerie"  ON galerie_photos  FOR SELECT USING (publie = true);
CREATE POLICY "public_read_videos"   ON galerie_videos  FOR SELECT USING (publie = true);
CREATE POLICY "public_read_avis"     ON avis_clients    FOR SELECT USING (approuve = true);
CREATE POLICY "public_read_settings" ON site_settings   FOR SELECT USING (true);

-- ── Écriture publique pour les avis (clients peuvent déposer) ──
CREATE POLICY "public_insert_avis" ON avis_clients
  FOR INSERT TO anon, authenticated WITH CHECK (true);

-- ── Admin : accès complet (nécessite d'être connecté) ──
CREATE POLICY "admin_all_blog"     ON blog_posts     FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "admin_all_galerie"  ON galerie_photos FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "admin_all_videos"   ON galerie_videos FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "admin_all_avis"     ON avis_clients   FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "admin_all_settings" ON site_settings  FOR ALL USING (auth.role() = 'authenticated');
```

---

## ÉTAPE 6 — Créer le Storage (pour photos et vidéos)

1. Supabase → **Storage** → **"New bucket"**
2. Nom : `Miralocks-media`
3. Cochez **"Public bucket"** ✅ (pour que les images soient accessibles)
4. Cliquez **"Create bucket"**

Puis dans **SQL Editor** :

```sql
-- Permettre l'upload aux utilisateurs connectés
CREATE POLICY "admin_upload" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'Miralocks-media'
    AND auth.role() = 'authenticated'
  );

-- Permettre la suppression aux utilisateurs connectés
CREATE POLICY "admin_delete" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'Miralocks-media'
    AND auth.role() = 'authenticated'
  );

-- Lecture publique des fichiers
CREATE POLICY "public_read" ON storage.objects
  FOR SELECT USING (bucket_id = 'Miralocks-media');
```

---

## ÉTAPE 7 — Déployer sur Hostinger

1. Connectez-vous à Hostinger → **hPanel** → **File Manager**
2. Allez dans `public_html`
3. Uploadez **tous les fichiers** du ZIP (en écrasant les existants)
4. Vérifiez que le fichier `.htaccess` est bien uploadé

---

## ÉTAPE 8 — Tester

1. Ouvrez **`https://www.Miralocks.com/admin.html`**
2. Connectez-vous avec votre email/mot de passe admin
3. Ajoutez un article de blog de test → vérifiez sur `blog.html`
4. Ajoutez une photo galerie → vérifiez sur `gallery.html`

---

## ✅ Récapitulatif des fichiers modifiés

| Fichier | Rôle |
|---------|------|
| `js/supabase.js` | API Supabase centralisée |
| `admin.html` | Interface d'administration |
| `blog.html` | Charge les articles depuis Supabase |
| `gallery.html` | Charge les photos + vidéos depuis Supabase |
| `avis.html` | Charge les avis approuvés + formulaire dépôt |

---

## ❓ Problèmes fréquents

**"Connexion échouée"** → Vérifiez l'email/mot de passe dans Supabase Authentication

**"Erreur 401"** → Vérifiez votre clé `SUPABASE_ANON` dans `supabase.js`

**Images qui ne s'affichent pas** → Vérifiez que le bucket est bien en mode Public

**"Table inexistante"** → Relancez le SQL de l'étape 4

---

*Guide rédigé pour Miralocks — Lomé, Togo*
