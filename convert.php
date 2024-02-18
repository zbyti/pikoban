<?php

$name = 'slide0';
$in = $name . '.c0';
$out = 'con_' . $in;

$file_r = fopen($in, 'rb');
$file_w = fopen($out, 'w+');

$bin_str = '';

if ($file_r === false) {
    die("Error opening file: $filename");
}

while (!feof($file_r)) {
    $byte = ord(fread($file_r, 1));
    $bin_str .= chr($byte + 16);
}

fclose($file_r);

fwrite($file_w, $bin_str);
fclose($file_w);

//-------------

$in = $name . '.c1';
$out = 'con_' . $in;

$file_r = fopen($in, 'rb');
$file_w = fopen($out, 'w+');

$bin_str = '';

if ($file_r === false) {
    die("Error opening file: $filename");
}

while (!feof($file_r)) {
    $byte = ord(fread($file_r, 1));
    $bin_str .= chr($byte + 16);
}

fclose($file_r);

fwrite($file_w, $bin_str);
fclose($file_w);

//-------------

$in = $name . '.c2';
$out = 'con_' . $in;

$file_r = fopen($in, 'rb');
$file_w = fopen($out, 'w+');

$bin_str = '';

if ($file_r === false) {
    die("Error opening file: $filename");
}

while (!feof($file_r)) {
    $byte = ord(fread($file_r, 1));
    $bin_str .= chr($byte + 16);
}

fclose($file_r);

fwrite($file_w, $bin_str);
fclose($file_w);

//-------------
