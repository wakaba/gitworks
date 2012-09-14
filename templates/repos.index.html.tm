<!DOCTYPE html>
<html t:params=$repository_url>
<t:call x="use URL::PercentEncode qw(percent_encode_c)">
<title t:parse><t:text value=$repository_url></title>

<h1>Repository <code><t:text value=$repository_url></code></h1>

<ul>
  <li>Repository URL: <code><t:text value=$repository_url></code>
  <li><a pl:href="'/repos/branches?repository_url=' . (percent_encode_c $repository_url)">Branches</a>
  <li><a pl:href="'/repos/tags?repository_url=' . (percent_encode_c $repository_url)">Tags</a>
  <li><a pl:href="'/repos/logs?repository_url=' . (percent_encode_c $repository_url)">Logs</a>
</ul>
