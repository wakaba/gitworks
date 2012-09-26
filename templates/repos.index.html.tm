<!DOCTYPE html>
<html t:params=$repository_url pl:data-repository-url=$repository_url>
<t:call x="use URL::PercentEncode qw(percent_encode_c)">
<title t:parse><t:text value=$repository_url></title>

<h1>Repository <code><t:text value=$repository_url></code></h1>

<dl>
  <dt>Repository URL
  <dd><code><t:text value=$repository_url></code>

  <dt>Branches
  <dd><ul id=list-branches data-template="
    <a href class=link-ref-name><code class=ref-name></code></a> <a href class=link-sha><code class=sha></code></a>
  "></ul>

  <dt>Tags
  <dd><ul id=list-logs data-template="
    <a href class=link-ref-name><code class=ref-name></code></a> <a href class=link-sha><code class=sha></code></a>
  "></ul>
</dl>

<script>
  function loadJSON (url, code) {
    var xhr = new XMLHttpRequest();
    xhr.open('GET', url, false);
    xhr.onreadystatechange = function () {
      if (xhr.readyState == 4) {
        if (xhr.status < 400) {
          code(JSON.parse(xhr.responseText));
        }
      }
    };
    xhr.send();
  }

  var repoURL = document.documentElement.getAttribute('data-repository-url');

  loadJSON('/repos/branches.json?repository_url=' + encodeURIComponent(repoURL), function (json) {
    var ul = document.getElementById('list-branches');
    var template = ul.getAttribute('data-template');
    for (var i = 0; i < json.length; i++) {
      var entry = json[i];
      var li = document.createElement('li');
      li.innerHTML = template;
      li.querySelector('.ref-name').textContent = entry.name;
      li.querySelector('.sha').textContent = entry.commit.sha.substring(0, 10);
      li.querySelector('.link-ref-name').href = '/repos/commits?sha=' + encodeURIComponent(entry.commit.name) + '&repository_url=' + encodeURIComponent(repoURL);
      li.querySelector('.link-sha').href = '/repos/commits?sha=' + encodeURIComponent(entry.commit.sha) + '&repository_url=' + encodeURIComponent(repoURL);
      ul.appendChild(li);
    }
  }, function () {
    var ul = document.getElementById('list-branches');
    var li = document.createElement('li');
    li.className = 'error';
    li.textContent = '(Error)';
    ul.appendChild(li);
  });

  loadJSON('/repos/tags.json?repository_url=' + encodeURIComponent(repoURL), function (json) {
    var ul = document.getElementById('list-tags');
    var template = ul.getAttribute('data-template');
    for (var i = 0; i < json.length; i++) {
      var entry = json[i];
      var li = document.createElement('li');
      li.innerHTML = template;
      li.querySelector('.ref-name').textContent = entry.name;
      li.querySelector('.sha').textContent = entry.commit.sha.substring(0, 10);
      li.querySelector('.link-ref-name').href = '/repos/commits?sha=' + encodeURIComponent(entry.commit.name) + '&repository_url=' + encodeURIComponent(repoURL);
      li.querySelector('.link-sha').href = '/repos/commits?sha=' + encodeURIComponent(entry.commit.sha) + '&repository_url=' + encodeURIComponent(repoURL);
      ul.appendChild(li);
    }
  }, function () {
    var ul = document.getElementById('list-tags');
    var li = document.createElement('li');
    li.className = 'error';
    li.textContent = '(Error)';
    ul.appendChild(li);
  });
</script>
