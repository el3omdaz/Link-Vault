import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import * as cheerio from 'cheerio';

const app = express();
const PORT = process.env.PORT || 8080;
const allowedOrigins = (process.env.ALLOWED_ORIGINS || '*').split(',').map(x => x.trim()).filter(Boolean);

app.use(helmet({ crossOriginResourcePolicy: false }));
app.use(cors({
  origin(origin, cb) {
    if (!origin || allowedOrigins.includes('*') || allowedOrigins.includes(origin)) return cb(null, true);
    return cb(new Error('Not allowed by CORS'));
  }
}));
app.use(express.json({ limit: '256kb' }));

function isHttpUrl(value) {
  try {
    const u = new URL(value);
    return u.protocol === 'http:' || u.protocol === 'https:';
  } catch {
    return false;
  }
}
function platformOf(url) {
  const s = String(url || '').toLowerCase();
  if (/youtube\.com|youtu\.be/.test(s)) return 'YouTube';
  if (/instagram\.com/.test(s)) return 'Instagram';
  if (/facebook\.com|fb\.com/.test(s)) return 'Facebook';
  if (/tiktok\.com/.test(s)) return 'TikTok';
  if (/twitter\.com|x\.com/.test(s)) return 'X / Twitter';
  if (/reddit\.com/.test(s)) return 'Reddit';
  return 'Web';
}
function clean(value) {
  return String(value || '').replace(/\s+/g, ' ').trim();
}
async function fetchWithTimeout(url, options = {}, timeoutMs = 9000) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(url, { ...options, signal: controller.signal });
  } finally {
    clearTimeout(timer);
  }
}
async function youtubeOembed(url) {
  const res = await fetchWithTimeout(`https://www.youtube.com/oembed?url=${encodeURIComponent(url)}&format=json`, {
    headers: { 'user-agent': 'LinkVault/1.0' }
  }, 7000);
  if (!res.ok) throw new Error('YouTube oEmbed failed');
  const data = await res.json();
  return {
    title: clean(data.title),
    description: '',
    image: data.thumbnail_url || '',
    author: data.author_name || '',
    canonicalUrl: url,
    platform: 'YouTube'
  };
}

app.get('/api/health', (_req, res) => {
  res.json({ ok: true, app: 'LinkVault Backend', time: new Date().toISOString() });
});

app.get('/api/metadata', async (req, res) => {
  const url = String(req.query.url || '').trim();
  if (!isHttpUrl(url)) return res.status(400).json({ error: 'Valid http/https url is required' });

  try {
    if (/youtube\.com|youtu\.be/i.test(url)) {
      return res.json(await youtubeOembed(url));
    }

    const response = await fetchWithTimeout(url, {
      redirect: 'follow',
      headers: {
        'user-agent': 'Mozilla/5.0 (compatible; LinkVaultBot/1.0; +https://linkvault.local)',
        'accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'accept-language': 'ar,en;q=0.8'
      }
    });
    if (!response.ok) throw new Error(`Fetch failed ${response.status}`);
    const contentType = response.headers.get('content-type') || '';
    if (!contentType.includes('text/html')) {
      return res.json({ title: '', description: '', image: '', canonicalUrl: url, platform: platformOf(url) });
    }

    const html = await response.text();
    const $ = cheerio.load(html);
    const meta = name => clean($(`meta[property="${name}"]`).attr('content') || $(`meta[name="${name}"]`).attr('content'));
    const title = meta('og:title') || meta('twitter:title') || clean($('title').first().text());
    const description = meta('og:description') || meta('twitter:description') || meta('description');
    let image = meta('og:image') || meta('twitter:image');
    const canonicalUrl = $('link[rel="canonical"]').attr('href') || meta('og:url') || url;
    if (image) {
      try { image = new URL(image, url).href; } catch { /* ignore */ }
    }
    return res.json({ title, description, image, canonicalUrl, platform: platformOf(url) });
  } catch (err) {
    return res.status(502).json({ error: 'Could not read metadata', platform: platformOf(url) });
  }
});

async function trailerFromTmdb(title) {
  if (!process.env.TMDB_API_KEY) return null;
  const searchUrl = new URL('https://api.themoviedb.org/3/search/movie');
  searchUrl.searchParams.set('api_key', process.env.TMDB_API_KEY);
  searchUrl.searchParams.set('query', title);
  searchUrl.searchParams.set('include_adult', 'false');
  searchUrl.searchParams.set('language', 'en-US');
  const search = await fetchWithTimeout(searchUrl);
  if (!search.ok) return null;
  const searchData = await search.json();
  const movie = searchData.results?.[0];
  if (!movie?.id) return null;

  const videosUrl = new URL(`https://api.themoviedb.org/3/movie/${movie.id}/videos`);
  videosUrl.searchParams.set('api_key', process.env.TMDB_API_KEY);
  videosUrl.searchParams.set('language', 'en-US');
  const videos = await fetchWithTimeout(videosUrl);
  if (!videos.ok) return null;
  const videosData = await videos.json();
  const pick = (videosData.results || []).find(v => v.site === 'YouTube' && v.type === 'Trailer' && v.official) ||
               (videosData.results || []).find(v => v.site === 'YouTube' && v.type === 'Trailer') ||
               (videosData.results || []).find(v => v.site === 'YouTube');
  if (!pick?.key) return null;
  return {
    trailerUrl: `https://www.youtube.com/watch?v=${pick.key}`,
    movieTitle: movie.title,
    source: 'tmdb'
  };
}
async function trailerFromYoutube(title) {
  if (!process.env.YOUTUBE_API_KEY) return null;
  const y = new URL('https://www.googleapis.com/youtube/v3/search');
  y.searchParams.set('key', process.env.YOUTUBE_API_KEY);
  y.searchParams.set('part', 'snippet');
  y.searchParams.set('type', 'video');
  y.searchParams.set('maxResults', '1');
  y.searchParams.set('q', `${title} official trailer`);
  const r = await fetchWithTimeout(y);
  if (!r.ok) return null;
  const data = await r.json();
  const videoId = data.items?.[0]?.id?.videoId;
  if (!videoId) return null;
  return {
    trailerUrl: `https://www.youtube.com/watch?v=${videoId}`,
    source: 'youtube'
  };
}

app.get('/api/trailer', async (req, res) => {
  const title = clean(req.query.title);
  if (!title) return res.status(400).json({ error: 'title is required' });
  const searchUrl = `https://www.youtube.com/results?search_query=${encodeURIComponent(`${title} official trailer`)}`;
  try {
    const tmdb = await trailerFromTmdb(title);
    if (tmdb) return res.json({ ...tmdb, searchUrl });
    const youtube = await trailerFromYoutube(title);
    if (youtube) return res.json({ ...youtube, searchUrl });
    return res.json({ trailerUrl: '', source: 'search', searchUrl });
  } catch {
    return res.json({ trailerUrl: '', source: 'search', searchUrl });
  }
});

app.listen(PORT, () => {
  console.log(`LinkVault backend listening on ${PORT}`);
});
