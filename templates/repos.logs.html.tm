<!DOCTYPE html>
<html t:params="$repository_url $logs">
<t:call x="use URL::PercentEncode qw(percent_encode_c)">
<title t:parse>Logs &mdash; <t:text value=$repository_url></title>

<h1><code><t:text value=$repository_url></code></h1>
<h2>Logs</h2>

<p>Repository <a pl:href="'/repos?repository_url=' . (percent_encode_c $repository_url)"><code><t:text value=$repository_url></code></a></p>

<t:call x="
sub _datetime ($) {
    my @time = gmtime $_[0];
    return sprintf '%04d-%02d-%02dT%02d:%02d:%02d-00:00',
        $time[5] + 1900, $time[4] + 1, $time[3], $time[2], $time[1], $time[0];
}
">

<t:for as=$log x="$logs">
  <article pl:id="'log-' . $log->{id}">
    <dl>
      <dt>sha
      <dd><a pl:href="'/repos/git/commits/' . $log->{sha} . '?repository_url=' . (percent_encode_c $repository_url)"><t:text value="$log->{sha}"></a>
        (<a pl:href="'/repos/git/commits/' . (percent_encode_c $log->{branch}) . '?repository_url=' . (percent_encode_c $repository_url)"><t:text value="$log->{branch}"></a>)
      <dt>Date
      <dd><time><t:text value="_datetime $log->{created}"></time>
      <dt>Data
      <dd><pre><t:text value="$log->{data}"></pre>
    </dl>
  </article>
</t:for>

<script src="http://suika.fam.cx/www/style/ui/time.js.u8" charset=utf-8></script><script>
  new TER (document.body);
</script>
