<!DOCTYPE html>
<html t:params="$urls $set_name">
<t:call x="use URL::PercentEncode qw(percent_encode_c)">

<title t:parse><t:text value="$set_name"></title>

<h1>Repository set <code><t:text value="$set_name"></code></h1>

<ul>
  <t:for as=$url x="[keys %$urls]">
    <li><a pl:href="'/repos?repository_url=' . percent_encode_c $url"><t:text value="$url"></a>
  </t:for>
</ul>
