# Brookie Backend Deployment Guide

This guide will help you deploy your Django backend to a remote server and configure your Flutter app to use it.

## 🚀 Quick Start - Railway Deployment (Recommended)

Railway is the easiest way to deploy your Django backend. It offers a generous free tier and automatic deployments.

### Step 1: Prepare Your Repository

1. Make sure all your changes are committed to Git:
   ```bash
   cd /Users/stergiosntontos/Documents/GitHub/Brookie
   git add .
   git commit -m "Add production deployment configuration"
   git push
   ```

### Step 2: Create Railway Account & Deploy

1. Go to [Railway.app](https://railway.app) and sign up with GitHub
2. Click **"New Project"** → **"Deploy from GitHub repo"**
3. Select your **Brookie** repository
4. Railway will automatically detect it's a Django app

### Step 3: Add PostgreSQL Database

1. In your Railway project, click **"+ New"** → **"Database"** → **"Add PostgreSQL"**
2. Railway will automatically create a `DATABASE_URL` environment variable

### Step 4: Configure Environment Variables

In Railway, go to your **web service** → **"Variables"** tab and add:

```
SECRET_KEY=your-random-secret-key-here-make-it-long-and-random
DEBUG=False
ALLOWED_HOSTS=*.up.railway.app,*.railway.app
```

**To generate a secure SECRET_KEY:**
```bash
python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"
```

### Step 5: Set Working Directory

In Railway → **Settings** → **Build & Deploy**:
- Set **Root Directory** to: `backend`
- Set **Start Command** to: `python manage.py migrate && gunicorn backend.wsgi:application --bind 0.0.0.0:$PORT`

### Step 6: Deploy!

1. Railway will automatically build and deploy
2. Wait for the deployment to complete (check the **Deployments** tab)
3. Once deployed, you'll get a URL like: `https://your-app.up.railway.app`

### Step 7: Get Your Backend URL

1. In Railway, go to **Settings** → **Networking**
2. Click **"Generate Domain"** to get a public URL
3. Copy this URL (e.g., `https://brookie-production.up.railway.app`)

---

## 📱 Configure Flutter App to Use Remote Server

### Option 1: Quick Toggle (For Testing)

1. Open `lib/config/api_config.dart`
2. Find this line:
   ```dart
   static const bool useRemoteServer = false;
   ```
3. Change it to:
   ```dart
   static const bool useRemoteServer = true;
   ```
4. Set your Railway URL:
   ```dart
   static const String remoteServerUrl = 'https://your-app.up.railway.app';
   ```

### Option 2: Environment-Based Configuration (Production)

For production builds, you can use different configurations:

1. **Development builds** (localhost):
   ```bash
   flutter run  # Uses localhost by default
   ```

2. **Production builds** (remote server):
   - Update `api_config.dart` with your remote URL
   - Build: `flutter build apk` or `flutter build ios`

---

## 🔄 Alternative: Render Deployment

If you prefer Render over Railway:

### Step 1: Create Render Account

1. Go to [Render.com](https://render.com) and sign up

### Step 2: Create PostgreSQL Database

1. Click **"New +"** → **"PostgreSQL"**
2. Name it `brookie-db`
3. Select **Free** tier
4. Click **"Create Database"**
5. Copy the **Internal Database URL** (starts with `postgres://`)

### Step 3: Create Web Service

1. Click **"New +"** → **"Web Service"**
2. Connect your GitHub repository
3. Configure:
   - **Name**: `brookie-backend`
   - **Root Directory**: `backend`
   - **Runtime**: Python 3
   - **Build Command**: `pip install -r requirements.txt && python manage.py collectstatic --noinput`
   - **Start Command**: `python manage.py migrate && gunicorn backend.wsgi:application`

### Step 4: Add Environment Variables

In Render, go to **Environment** and add:

```
SECRET_KEY=<your-random-secret-key>
DEBUG=False
DATABASE_URL=<paste-internal-database-url-from-step-2>
ALLOWED_HOSTS=*.onrender.com
```

### Step 5: Deploy & Get URL

1. Click **"Create Web Service"**
2. Wait for deployment (first build takes ~5-10 minutes)
3. Your URL will be: `https://brookie-backend.onrender.com`

---

## ✅ Verify Deployment

### Test Your Backend

1. Open your backend URL in a browser: `https://your-app.up.railway.app/api/`
2. You should see a Django REST Framework page or API response

### Test from Flutter App

1. Update `api_config.dart` with your remote URL
2. Run your Flutter app:
   ```bash
   flutter run
   ```
3. Try logging in or making API calls
4. Check the console for connection logs

---

## 🐛 Troubleshooting

### Issue: "502 Bad Gateway" or "Application Error"

**Solution**: Check Railway/Render logs:
- Railway: Go to **Deployments** tab → Click on latest deployment → View logs
- Render: Go to your service → **Logs** tab

Common causes:
- Missing environment variables (check `SECRET_KEY`, `DATABASE_URL`)
- Database not connected properly
- Port binding issues (make sure using `$PORT` variable)

### Issue: Flutter app can't connect to backend

**Checklist**:
1. ✅ Is `useRemoteServer = true` in `api_config.dart`?
2. ✅ Is `remoteServerUrl` set correctly (with `https://`)?
3. ✅ Does your backend URL work in a browser?
4. ✅ Check CORS settings in Django (should allow Flutter app origin)

### Issue: "ALLOWED_HOSTS" error

**Solution**: Add your Railway/Render domain to `ALLOWED_HOSTS` environment variable:
```
ALLOWED_HOSTS=your-app.up.railway.app,*.railway.app
```

### Issue: Static files not loading

**Solution**: Run collect static manually:
```bash
# In Railway/Render shell
python manage.py collectstatic --noinput
```

---

## 🔐 Security Best Practices

### Before Going to Production:

1. **Generate a new SECRET_KEY** (never use the default one)
2. **Set DEBUG=False** in production
3. **Configure ALLOWED_HOSTS** properly (don't use `*`)
4. **Use HTTPS only** (Railway/Render provide this automatically)
5. **Update CORS settings** to only allow your Flutter app origin:
   ```python
   CORS_ALLOWED_ORIGINS = [
       "http://localhost:3000",  # Flutter web development
       "https://your-flutter-app.com",  # Your production Flutter web app
   ]
   ```

---

## 📊 Database Management

### Run Migrations

Railway:
```bash
# Migrations run automatically on each deployment
# Or manually in Railway shell
python manage.py migrate
```

Render:
- Migrations run automatically via start command
- Or use Render Shell: `python manage.py migrate`

### Access Database

Railway:
1. Go to **PostgreSQL service** → **Data** tab
2. Or use connection string for local access

Render:
1. Go to your **PostgreSQL database** → **Connect** tab
2. Use provided connection string

---

## 🔄 Switching Between Local and Remote

### For Development (Localhost):
```dart
// lib/config/api_config.dart
static const bool useRemoteServer = false;
```

### For Testing Remote Server:
```dart
// lib/config/api_config.dart
static const bool useRemoteServer = true;
static const String remoteServerUrl = 'https://your-app.up.railway.app';
```

### For Production Builds:
Always set `useRemoteServer = true` with your production backend URL before building release versions.

---

## 📞 Need Help?

If you run into issues:
1. Check Railway/Render deployment logs
2. Verify environment variables are set correctly
3. Test backend URL directly in browser
4. Check Flutter app console for error messages
5. Review Django settings for ALLOWED_HOSTS and CORS

---

## 🎉 You're All Set!

Your Django backend is now deployed and accessible from anywhere. Your Flutter app can connect to it whether you're developing locally or testing on real devices.

**Next steps:**
- Set up automatic deployments (Railway/Render do this by default with GitHub)
- Configure custom domain (optional)
- Set up monitoring and error tracking
- Add database backups
