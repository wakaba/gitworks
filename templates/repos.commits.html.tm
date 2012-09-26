<!DOCTYPE html>
<html t:params="$repository_url $commits $commit_statuses">
<t:call x="use URL::PercentEncode qw(percent_encode_c)">
<t:call x="use GW::Defs::Statuses">
<title t:parse>Commits &mdash; <t:text value=$repository_url></title>

<h1><code><t:text value=$repository_url></code></h1>
<h2>Commits</h2>

<p>Repository <a pl:href="'/repos?repository_url=' . (percent_encode_c $repository_url)"><code><t:text value=$repository_url></code></a></p>

<t:for as=$commit x="$commits">
  <article pl:id="'commit-' . $commit->{sha}">
    <dl>
      <dt>sha
      <dd><a pl:href="'/repos/git/commits/' . $commit->{sha} . '?repository_url=' . (percent_encode_c $repository_url)"><t:text value="$commit->{sha}"></a>
      <dt>Author
      <dd><t:text value="$commit->{author}->{name}">
      <dt>Date
      <dd><time><t:text value="$commit->{author}->{date}"></time>
      <dt>Commit log
      <dd><t:text value="$commit->{message}">

      <t:my as=$commit_status x="$commit_statuses->{$commit->{sha}}">
      <t:if x=$commit_status>
        <dt>Status
        <t:for as=$status x="$commit_status">
          <dd pl:id="'commit-status-' . $status->{id}">
            <a pl:href="$status->{target_url}"><t:text value="$GW::Defs::Statuses::CommitStatusCodeToName->{$status->{state}}"></a>:
            <t:text value="$status->{description}">
        </t:for>
      </t:if>
    </dl>
  </article>
</t:for>

<script src="http://suika.fam.cx/www/style/ui/time.js.u8" charset=utf-8></script><script>
  new TER (document.body);
</script>
