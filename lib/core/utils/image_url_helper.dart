class ImageUrlHelper {
  static String fix(String? url) {
    if (url == null || url.isEmpty || url.contains("null")) {
      // Return a default placeholder avatar if URL is missing
      return "https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png";
    }

    // If it's already a full URL (Google/Facebook/Cloudinary)
    if (url.startsWith("http")) {
      return url;
    }

    // Fix slashes for local API paths
    final cleanUrl = url.startsWith('/') ? url.substring(1) : url;

    // Base URL of your API
    return "https://clikkme.in/$cleanUrl";
  }
}